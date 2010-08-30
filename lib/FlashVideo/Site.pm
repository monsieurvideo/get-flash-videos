# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site;

use strict;

# Various accessors to avoid plugins needing to know about the exact command
# line options. This will improve at some point (i.e. more OO)

sub debug {
  $App::get_flash_videos::opt{debug};
}

sub action {
  $App::get_flash_videos::opt{play} ? "play" : "download";
}

sub player {
  $App::get_flash_videos::opt{player};
}

sub yes {
  $App::get_flash_videos::opt{yes};
}

sub quiet {
  $App::get_flash_videos::opt{quiet};
}

1;
