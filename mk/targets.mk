ifeq ($(findstring release,$(MAKECMDGOALS)),release)
  export SCRIPT = $(BASEEXT)-$(VERSION)
else
  export SCRIPT = $(INST_SCRIPT)/$(BASEEXT)
endif

# Extra targets
COMBINE = $(PERL) -I$(INST_LIB) utils/combine-perl.pl

EXTRATARGETS = combined-$(BASEEXT) combined-$(BASEEXT)-$(VERSION) $(BASEEXT)-$(VERSION)

# Build the main get_flash_videos, by combining the modules and sites into one
# file, for easier download and installation.

$(BASEEXT)-$(VERSION): $(INST_SCRIPT)/$(BASEEXT) pm_to_blib .sitemodules \
  utils/combine-header
	$(COMBINE) --name="$(BASEEXT)" --include="^FlashVideo::" \
	  utils/combine-header .sitemodules $(INST_SCRIPT)/$(BASEEXT) > $@
	chmod a+x $@

# This makes sure to 'use' all the Site modules, so that the combiner can pick
# them all up.
.sitemodules: lib/FlashVideo/Site/*.pm
	ls $< | sed -e 's!lib/!!' -e 's!/!::!g' -e 's/\.pm$$/ ();/' -e 's/^/use /' > $@

# Build a combined version which also includes our dependencies, this makes it
# easier for people who cannot install Perl modules. (Note that it does still
# need HTML::Parser, as this is XS, and optionally XML::Simple, but LWP and
# Mechanize are included by this).

COMBINED_SOURCES = utils/combine-head .sitemodules $(INST_SCRIPT)/$(BASEEXT)

combined-$(BASEEXT)-$(VERSION): combined-get_flash_videos
	cp -p $^ $@

combined-$(BASEEXT): $(COMBINED_SOURCES)
	$(COMBINE) --name="$@" $(COMBINED_SOURCES) > $@
	chmod a+x $@

clean:: extraclean

extraclean:
	rm -f $(EXTRATARGETS) .sitemodules MANIFEST MANIFEST.bak $(DISTVNAME).tar$(SUFFIX)

