# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Msn;
use strict;
use FlashVideo::Utils;
use FlashVideo::Site::Bing;

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;

  # Since MSN videos are the same as Bing videos, use the Bing package
  return FlashVideo::Site::Bing::find_video($self, $browser, $embed_url, $prefs);
}

1;
