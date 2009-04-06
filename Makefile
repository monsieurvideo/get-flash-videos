MAIN = get_flash_videos
VERSION := $(shell ./$(MAIN) --version 2>&1 | awk '{print $$3}')

TARGETS = combined-$(MAIN) $(MAIN)-$(VERSION)

all: $(TARGETS)

clean:
	rm -f $(TARGETS) .sitemodules

release: $(MAIN)-$(VERSION) wiki-update release-combined
	googlecode_upload.py -l "Featured,OpSys-All" -s "Version $(VERSION)" -p get-flash-videos $^
	svn commit -m "Version $(VERSION)" wiki/Installation.wiki

$(MAIN)-$(VERSION): $(COMBINE) $(MAIN) FlashVideo/* .sitemodules
	$(COMBINE) --include="^FlashVideo::" $(MAIN) .sitemodules > $@
	chmod a+x $@

COMBINE = utils/combine-perl.pl
COMBINED_SOURCES = experiments/combine-head $(MAIN) .sitemodules

release-combined: combined-$(MAIN)-$(VERSION)
	googlecode_upload.py -l "Featured,OpSys-All" -s "Version $(VERSION) -- combined version including some required modules." -p get-flash-videos $^

combined-$(MAIN)-$(VERSION): combined-get_flash_videos
	cp -p $^ $@

combined-$(MAIN): $(COMBINE) $(COMBINED_SOURCES)
	$(COMBINE) $(COMBINED_SOURCES) > $@
	chmod a+x $@

check: $(MAIN)
	$(MAKE) -C t $@

.sitemodules: FlashVideo/Site/*.pm
	ls $^ | sed -e 's!/!::!g' -e 's/\.pm$$/ ();/' -e 's/^/use /' > $@

wiki:
	svn checkout https://get-flash-videos.googlecode.com/svn/wiki/ $@

wiki-update: wiki
	@cd wiki && svn up
	@perl -pi -e's/$(MAIN)-\d+\.\d+/$(MAIN)-$(VERSION)/g' wiki/Installation.wiki
	@svn diff wiki/Installation.wiki | grep -q . || (echo "Version already released" && exit 1)
	@svn diff wiki/Installation.wiki && echo "OK? (ctrl-c to abort)" && read F


.PHONY: all clean release release-combined check wiki-update
