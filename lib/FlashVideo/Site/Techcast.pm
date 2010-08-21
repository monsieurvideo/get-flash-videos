# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Techcast;

use strict;
use FlashVideo::Utils;
use HTML::Entities;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my($clip_url) = $browser->content =~ /clip:\s*{\s*url:\s*['"]([^"']+)/;
  die "Unable to extract clip URL" unless $clip_url;
  $clip_url = URI->new_abs($clip_url, $browser->uri);

  my($talk) = $browser->content =~ /class="lecture_archive"[^>]+>([^<]+)/i;
  $talk = decode_entities($talk);

  my($author) = $browser->content =~ /class="speaker_archive"[^>]+>([^<]+)/i;
  $author = decode_entities($author);

  return $clip_url, title_to_filename($talk ? "$author - $talk" : $clip_url);
}

1;
