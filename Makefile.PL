#!perl -w
use strict;
use ExtUtils::MakeMaker;

my %mm_vars = (
    AUTHOR             => 'Monsieur Video <monsieurvideo@gmail.com>',
    NAME               => 'App::get_flash_videos',
    VERSION_FROM       => "bin/get_flash_videos",
    EXE_FILES          => ["bin/get_flash_videos"],
    MAN1PODS           => {
      'doc/get_flash_videos.pod' => 'blib/man1/get_flash_videos.1',
    },

    # Avoid man pages for modules for now.
    MAN3PODS           => {},

    PREREQ_PM          => {
      URI              => 0,
      'LWP::UserAgent' => 0,
      'WWW::Mechanize' => 0,
    },


    FIRST_MAKEFILE   => "mk/makemaker.mk",
);

# Needed for reasonable UTF-8 support, also modules are used that are
# core perl as reported by 'corelist' since 5.8.
if($ExtUtils::MakeMaker::VERSION >= 6.48) {
  $mm_vars{MIN_PERL_VERSION} = 5.008;
}

if($ExtUtils::MakeMaker::VERSION >= 6.46) {
    $mm_vars{META_MERGE} = {
      resources        => {
        license        => 'http://www.apache.org/licenses/LICENSE-2.0.html',
        bugtracker     => 'http://code.google.com/p/get-flash-videos/issues',
        repository     => 'http://github.com/monsieurvideo/get-flash-videos',
      }
    };
}

my $build_req;
if($ExtUtils::MakeMaker::VERSION >= 6.55) {
  $build_req = $mm_vars{BUILD_REQUIRES} ||= {};
} else {
  $build_req = $mm_vars{PREREQ_PM};
}

# Needed for consistent order in t/rtmpdownloader.t
$build_req->{"Tie::IxHash"} = 0;

WriteMakefile(%mm_vars);
