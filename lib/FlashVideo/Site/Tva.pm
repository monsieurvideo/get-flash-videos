# Part of get-flash-videos. See get_flash_videos for copyright.
=for comment
   Uses TVA/Canoe-Specific way to get the brightcove metadata, 
    then forwards to the brightcove module.
 
   TVA/Canoe live streaming
   expects URL of the form
      http://tva.canoe.ca/dws/?emission=xxxxxxx
=cut
package FlashVideo::Site::Tva;

use strict;
use FlashVideo::Utils;
use base 'FlashVideo::Site::Brightcove';

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  # look inside script that generates CanoeVideoStandalone object
  my $video_id  = ($browser->content =~ /player.SetVideo.(\d+)/i)[0];
  my $player_id = ($browser->content =~ /player.SetPlayer.(\d+)/i)[0];

  debug "Extracted playerId: $player_id, videoId: $video_id"
    if $player_id or $video_id;

  if(!$video_id) {
    # Some pages use more complex video[x][3] type code..
    my $video_offset = ($browser->content =~ /player.SetVideo.\w+\[(\d+)/i)[0];
    $video_id = ($browser->content =~ /videos\[$video_offset\].+'(\d+)'\s*\]/)[0];
  }

  die "Unable to extract Brightcove IDs from page"
    unless $player_id and $video_id;

  return $self->amfgateway($browser, $player_id, { videoId => $video_id, } );
}

sub can_handle {
  my($self, $browser, $url) = @_;

  return $browser->content =~ /player = CanoeVideoStandalone\.create\(\);/i;
}

1;
