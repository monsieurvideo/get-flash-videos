# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Last;

use strict;
use FlashVideo::Utils;
use URI::Escape;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my($artist, $id) = $embed_url =~ m{/([^/]+)/\+videos/(\d+)};
  my($title) = $browser->content =~ /<h1>([^<]+)/;

  die "No video ID found" unless $id;

  $browser->get("http://ext.last.fm/1.0/video/getplaylist.php?&vid=$id&artist=$artist");

  return $browser->content =~ /<location>([^<]+)/, title_to_filename($title);
}

sub can_handle {
  my($self, $browser, $url) = @_;

  # Don't trigger on YouTube IDs
  return $url =~ /last\.fm/ && $url =~ m{\+video/\d{2,}};
}

1;
