# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Cultureunplugged;

use strict;
use FlashVideo::JSON;
use FlashVideo::Utils;
use URI::Escape;

our $VERSION = '0.01';
sub Version() { $VERSION; }

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my ($id, $title) = $embed_url =~ m{/play/(\d+)/(.*?)};

  die "No video ID found" unless $id;

  $browser->get("http://www.cultureunplugged.com/ajax/getMovieInfo.php?movieId=$id&type=");
  my ($json) = from_json($browser->content);
  return $json->{'url'}, title_to_filename($json->{'title'}, "mp4");
}

1;
