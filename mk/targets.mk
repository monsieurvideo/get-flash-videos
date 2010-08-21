ifeq ($(findstring release,$(MAKECMDGOALS)),release)
  export SCRIPT = $(BASEEXT)-$(VERSION)
else
  export SCRIPT = $(INST_SCRIPT)/$(BASEEXT)
endif

# Extra targets
COMBINE = utils/combine-perl.pl

EXTRATARGETS = combined-$(BASEEXT) combined-$(BASEEXT)-$(VERSION) $(BASEEXT)-$(VERSION)

# Ensure our Perl tests have the combined version available
pure_all:: $(BASEEXT)-$(VERSION)

# Build the main get_flash_videos, by combining the modules and sites into one
# file, for easier download and installation.

COMBINED_SOURCES = utils/combine-head .sitemodules $(BASEEXT)

$(BASEEXT)-$(VERSION): $(COMBINE) $(INST_SCRIPT)/$(BASEEXT) $(INST_LIB)/FlashVideo/* .sitemodules \
  utils/combine-header
	$(COMBINE) --name="$(BASEEXT)" --include="^FlashVideo::" \
	  utils/combine-header .sitemodules $(BASEEXT) > $@
	chmod a+x $@

# This makes sure to 'use' all the Site modules, so that the combiner can pick
# them all up.
.sitemodules: $(INST_LIB)/FlashVideo/Site/*.pm
	ls $^ | sed -e 's!/!::!g' -e 's/\.pm$$/ ();/' -e 's/^/use /' > $@

# Build a combined version which also includes our dependencies, this makes it
# easier for people who cannot install Perl modules. (Note that it does still
# need HTML::Parser, as this is XS, and optionally XML::Simple, but LWP and
# Mechanize are included by this).

combined-$(MAIN)-$(VERSION): combined-get_flash_videos
	cp -p $^ $@

combined-$(MAIN): $(COMBINE) $(COMBINED_SOURCES)
	$(COMBINE) --name="$@" $(COMBINED_SOURCES) > $@
	chmod a+x $@

clean:: extraclean

extraclean:
	rm -f $(TARGETS) .sitemodules

