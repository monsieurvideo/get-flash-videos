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
  if ($embed_url =~ /(http:\/\/www.munkvideo.cz\/video\/[^?]{37})?.*/) {
    $url = "$1?munkvideo=original";
  } else {
    # if we can't get it, just leave as the video URL is there
    return;
  }

#  $browser->allow_redirects;
  # obtained URL will be redirected
  $browser->get($url);
  $url = $browser->response->header('Location');
  debug("URL: '" . $url . "'");

  return $url, title_to_filename($url);
}

1;
