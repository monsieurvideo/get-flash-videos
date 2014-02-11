# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Four;

use strict;

use base qw(FlashVideo::Site::Tv3);

our $VERSION = '0.01';
sub Version() { $VERSION; }

sub getSloc($) {
  return "four";
}

1;
