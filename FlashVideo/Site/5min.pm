# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::5min;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser) = @_;

  my $filename = title_to_filename(extract_info($browser)->{meta_title});

  # They now pass the URL as a param, so the generic code can extract it.
  my $url = (FlashVideo::Generic->find_video($browser, $browser->uri))[0];

  return $url, $filename;
}

1;
