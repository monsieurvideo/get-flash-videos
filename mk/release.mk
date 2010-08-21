# For project people to easily make releases.

# Put this in ~/bin:
#  http://code.google.com/p/support/source/browse/trunk/scripts/googlecode_upload.py

release: release-main deb
	svn commit -m "Version $(VERSION)" wiki/Installation.wiki wiki/Version.wiki

release-main: $(BASEEXT)-$(VERSION) changelog-update wiki-update release-combined
	googlecode_upload.py -l "Featured,OpSys-All" -s "Version $(VERSION)" -p get-flash-videos $<
	git commit -m "Version $(VERSION)" debian/changelog
	git tag -a -m "Version $(VERSION)" v$(VERSION)
	git push origin v$(VERSION)

release-combined: combined-$(BASEEXT)-$(VERSION)
	googlecode_upload.py -l "OpSys-All" -s "Version $(VERSION) -- combined version including some required modules." -p get-flash-videos $^

wiki:
	svn checkout https://get-flash-videos.googlecode.com/svn/wiki/ $@

changelog-update:
	@fgrep -q '$(BASEEXT) ($(VERSION)-1)' debian/changelog || dch -v $(VERSION)-1

wiki-update: wiki
	@cd wiki && svn up
	@perl -pi -e's/(get[-_]flash[-_]videos[-_])\d+\.\d+/$${1}$(VERSION)/g' wiki/Installation.wiki
	@perl -pi -e's/\d+\.\d+/$(VERSION)/g' wiki/Version.wiki
	@svn diff wiki/Installation.wiki wiki/Version.wiki | grep -q . || (echo "Version already released" && exit 1)
	@svn diff wiki/Installation.wiki wiki/Version.wiki && echo "OK? (ctrl-c to abort)" && read F

deb: release-main
	mkdir -p /tmp/deb
	git archive --prefix=v$(VERSION)/ v$(VERSION) | tar -xvf - -C /tmp/deb
	cd /tmp/deb/v$(VERSION) && (dpkg-buildpackage || echo "Ignoring return value..")
	googlecode_upload.py -l "Type-Package,OpSys-Linux" -s "Version $(VERSION) -- Debian package, for Debian and Ubuntu" -p get-flash-videos /tmp/deb/get-flash-videos_$(VERSION)-1_all.deb
	rm -rf /tmp/deb/v$(VERSION)

