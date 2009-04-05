MAIN = get_flash_videos
VERSION := $(shell ./$(MAIN) --version 2>&1 | awk '{print $$3}')

TARGETS = combined-$(MAIN)

all: $(TARGETS)

COMBINE = utils/combine-perl.pl
COMBINED_SOURCES = experiments/combine-head $(MAIN)

combined-get_flash_videos: $(COMBINE) $(COMBINED_SOURCES)
	$(COMBINE) $(COMBINED_SOURCES) > $@

clean:
	rm -f $(TARGETS) $(MAIN)-$(VERSION)

release: $(MAIN)-$(VERSION) 
	googlecode_upload.py -s "Version $(VERSION)" -p get-flash-videos $^

$(MAIN)-$(VERSION):
	cp -p $(MAIN) $@

release-combined: combined-$(MAIN)-$(VERSION)
	googlecode_upload.py -s "Version $(VERSION) -- combined version including some required modules." -p get-flash-videos $^

combined-$(MAIN)-$(VERSION): combined-get_flash_videos
	cp -p $^ $@
