#!perl -w
use strict;
use ExtUtils::MakeMaker;

WriteMakefile(
    AUTHOR           => 'Monsieur Video <monsieurvideo@gmail.com>',
    NAME             => 'App::get_flash_videos',
    VERSION_FROM     => "bin/get_flash_videos",
    EXE_FILES        => ["bin/get_flash_videos"],
    MAN1PODS         => {
      'doc/get_flash_videos.pod' => 'blib/man1/get_flash_videos.1',
    },
    # Avoid man pages for modules for now.
    MAN3PODS         => {},
    # Needed for reasonable UTF-8 support, also modules are used that are
    # core perl as reported by 'corelist' since 5.8.
    MIN_PERL_VERSION => 5.008,
    PREREQ_PM        => {
      URI              => 0,
      'LWP::UserAgent' => 0,
      'WWW::Mechanize' => 0,
    },
    BUILD_REQUIRES   => {
      # Needed for consistent order in t/rtmpdownloader.t
      "Tie::IxHash"        => 0,
      # utils/combine-perl uses this
      "UNIVERSAL::require" => 0,
    },

    FIRST_MAKEFILE   => "mk/makemaker.mk",
);

