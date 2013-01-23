# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Redtube;

use strict;
use FlashVideo::Utils;
use URI::Escape;

sub find_video {
  my($self, $browser, $embed_url) = @_;

  my($title) = extract_title($browser) =~ /(.*) \|/;

  my($url) = $browser->content =~ /mp4_url=([^&"]+)/;
  $url = uri_unescape($url);

  $browser->allow_redirects;
  return $url, title_to_filename($title, "mp4");
}

1;
