TARGETS = combined-get_flash_videos

all: $(TARGETS)

COMBINE = utils/combine-perl.pl
COMBINED_SOURCES = experiments/combine-head get_flash_videos

combined-get_flash_videos: $(COMBINE) $(COMBINED_SOURCES)
	$(COMBINE) $(COMBINED_SOURCES) > $@

clean:
	rm -f $(TARGETS)
