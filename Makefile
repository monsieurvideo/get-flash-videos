all::

mk/makemaker-wrap.mk: Makefile.PL
	@if [ ! -f "mk/makemaker.mk" ]; then perl Makefile.PL; fi
	@echo "-include mk/makemaker.mk" > $@

-include mk/makemaker-wrap.mk
include mk/targets.mk
include mk/release.mk
