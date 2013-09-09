# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Munkvideo;

use strict;
use FlashVideo::Utils;
use URI::Escape;

our $VERSION = '0.01';
sub Version() { $VERSION; }

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my $url = "";


  # read URL from the configuration passed to flash player
  if ($browser->content =~ /\s*res0: "(http:\/\/www.munkvideo.cz\/video\/[^?]+?munkvideo=original),.*/) {
    $url = $1;
  } else {
    # if we can't get it, just leave as the video URL is there
    return;
  }

  debug("URL: '" . $url . "'");

  return $url, title_to_filename($url);
}

1;
