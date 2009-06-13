# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::About;

use strict;
use FlashVideo::Utils;
use base 'FlashVideo::Site::Brightcove';

my $JS_RE = qr/vdo_None\.js/;

sub find_video {
  my($self, $browser, $embed_url) = @_;

  my($video_ref) = $browser->content =~ /zIvdoId=["']([^"']+)/;
  die "Unable to extract video ref" unless $video_ref;

  my($js_src) = $browser->content =~ /["']([^"']+$JS_RE)/;
  $browser->get($js_src);
  my($player_id) = $browser->content =~ /playerId.*?(\d+)/;
  die "Unable to extract playerId" unless $player_id;

  return $self->amfgateway($browser, $player_id, undef, $video_ref);
}

sub can_handle {
  my($self, $browser, $url) = @_;

  # can only handle videos embedded with this javascript code.
  return $browser->content =~ $JS_RE; 
}

1;
