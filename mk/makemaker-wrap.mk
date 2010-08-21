mk/makemaker.mk: Makefile.PL
	# If you want to use a different perl run Makefile.PL yourself before make.
	perl Makefile.PL

-include mk/makemaker.mk
