MAIN = get_flash_videos
VERSION := $(shell ./$(MAIN) --version 2>&1 | awk '{print $$3}')

TARGETS = combined-$(MAIN) $(MAIN)-$(VERSION)

all: $(TARGETS)

clean:
	rm -f $(TARGETS) .sitemodules

release: $(MAIN)-$(VERSION) 
	googlecode_upload.py -s "Version $(VERSION)" -p get-flash-videos $^

$(MAIN)-$(VERSION): $(COMBINE) $(MAIN) FlashVideo/* .sitemodules
	$(COMBINE) --include="^FlashVideo::" $(MAIN) .sitemodules > $@
	chmod a+x $@

COMBINE = utils/combine-perl.pl
COMBINED_SOURCES = experiments/combine-head $(MAIN) .sitemodules

release-combined: combined-$(MAIN)-$(VERSION)
	googlecode_upload.py -s "Version $(VERSION) -- combined version including some required modules." -p get-flash-videos $^

combined-$(MAIN)-$(VERSION): combined-get_flash_videos
	cp -p $^ $@

combined-$(MAIN): $(COMBINE) $(COMBINED_SOURCES)
	$(COMBINE) $(COMBINED_SOURCES) > $@
	chmod a+x $@

check: $(MAIN)
	$(MAKE) -C t $@

.sitemodules: FlashVideo/Site/*.pm
	ls $^ | sed -e 's!/!::!g' -e 's/\.pm$$/ ();/' -e 's/^/use /' > $@

