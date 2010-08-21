# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Mylifetime;

use strict;
use FlashVideo::Utils;
use base 'FlashVideo::Site::Brightcove';

my $JS_RE = qr/displayFlash\(/;

sub find_video {
  my($self, $browser, $embed_url) = @_;

  my($player_id, $video_id) = $browser->content =~ /$JS_RE\s*"(\d+)",\s*"(\d+)"/;
  die "Unable to extract video ids" unless $video_id;

  return $self->amfgateway($browser, $player_id, { videoId => $video_id });
}

sub can_handle {
  my($self, $browser, $url) = @_;

  # can only handle videos embedded with this javascript code.
  return $browser->content =~ $JS_RE; 
}

1;
