#!/bin/ksh

# 
#VER=1.24.`date +%Y%m%d`
#GVER=1.24-git-`date +%Y%m%d`
#ARCNAME=App-get_flash_videos-${VER}
#git tag v${VER}
#env GFV_DEVEL_MODE=1 perl Makefile.PL
#echo "-include mk/makemaker.mk">mk/makemaker-wrap.mk
#make -f Makefile.bsd-wrapper VERSION=${VER} mk/makemaker-wrap.mk
#make -f Makefile.bsd-wrapper VERSION=${VER} release-test

make -f Makefile.bsd-wrapper mk/makemaker-wrap.mk
make -f Makefile.bsd-wrapper release-test
