MAIN = get_flash_videos
COMBINE = utils/combine-perl.pl
VERSION := $(shell ./$(MAIN) --version 2>&1 | awk '{print $$3}')

TARGETS = combined-$(MAIN) combined-$(MAIN)-$(VERSION) \
	  $(MAIN)-$(VERSION) $(MAIN).1 $(MAIN).1.gz

all: $(MAIN)-$(VERSION)

clean:
	rm -f $(TARGETS) .sitemodules

# Build the main get_flash_videos, by combining the modules and sites into one
# file, for easier download and installation.

$(MAIN)-$(VERSION): $(COMBINE) $(MAIN) FlashVideo/* .sitemodules
	$(COMBINE) --name="$(MAIN)" --include="^FlashVideo::" $(MAIN) .sitemodules > $@
	chmod a+x $@

# This makes sure to 'use' all the Site modules, so that the combiner can pick
# them all up.

.sitemodules: FlashVideo/Site/*.pm
	ls $^ | sed -e 's!/!::!g' -e 's/\.pm$$/ ();/' -e 's/^/use /' > $@

# Build a combined version which also includes our dependencies, this makes it
# easier for people who cannot install Perl modules. (Note that it does still
# need HTML::Parser, as this is XS, and optionally XML::Simple, but LWP and
# Mechanize are included by this).

COMBINED_SOURCES = utils/combine-head $(MAIN) .sitemodules

combined-$(MAIN)-$(VERSION): combined-get_flash_videos
	cp -p $^ $@

combined-$(MAIN): $(COMBINE) $(COMBINED_SOURCES)
	$(COMBINE) --name="$@" $(COMBINED_SOURCES) > $@
	chmod a+x $@

# Run our Perl tests.
check: $(MAIN)
	$(MAKE) -C t $@

# Manpage
$(MAIN).1: $(MAIN).pod
	pod2man -c "User commands" -r "$(MAIN)-$(VERSION)" $^ > $@

$(MAIN).1.gz: $(MAIN).1
	gzip $^

# Install
DESTDIR ?=
install: $(MAIN)-$(VERSION) $(MAIN).1.gz
	mkdir -p $(DESTDIR)/usr/bin
	cp -p $(MAIN)-$(VERSION) $(DESTDIR)/usr/bin/$(MAIN)
	mkdir -p $(DESTDIR)/usr/man/man1
	cp -p $(MAIN).1.gz $(DESTDIR)/usr/man/man1

# For project people to easily make releases.

# Put this in ~/bin:
#  http://code.google.com/p/support/source/browse/trunk/scripts/googlecode_upload.py

release: $(MAIN)-$(VERSION) changelog-update wiki-update release-combined
	googlecode_upload.py -l "Featured,OpSys-All" -s "Version $(VERSION)" -p get-flash-videos $<
	svn commit -m "Version $(VERSION)" wiki/Installation.wiki wiki/Version.wiki
	svn commit -m "Version $(VERSION)" debian/changelog

release-combined: combined-$(MAIN)-$(VERSION)
	googlecode_upload.py -l "Featured,OpSys-All" -s "Version $(VERSION) -- combined version including some required modules." -p get-flash-videos $^

wiki:
	svn checkout https://get-flash-videos.googlecode.com/svn/wiki/ $@

changelog-update:
	@fgrep -q '$(MAIN) ($(VERSION)-1)' debian/changelog || dch -v $(VERSION)-1

wiki-update: wiki
	@cd wiki && svn up
	@perl -pi -e's/$(MAIN)-\d+\.\d+/$(MAIN)-$(VERSION)/g' wiki/Installation.wiki
	@perl -pi -e's/\d+\.\d+/$(VERSION)/g' wiki/Version.wiki
	@svn diff wiki/Installation.wiki wiki/Version.wiki | grep -q . || (echo "Version already released" && exit 1)
	@svn diff wiki/Installation.wiki wiki/Version.wiki && echo "OK? (ctrl-c to abort)" && read F

.PHONY: all clean release release-combined check wiki-update install
