# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Fora;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my($clip_id) = $browser->content =~ /clipid=(\d+)/;
  die "Unable to extract clipid" unless $clip_id;

  $browser->get("http://fora.tv/fora/fora_player_full?cid=$clip_id&h=1&b=0");

  my $xml = from_xml($browser);

  my $filename = title_to_filename($xml->{clipinfo}->{clip_title});

  my $playpath = $xml->{encodeinfo}->{encode_url};
  $playpath =~ s/\.flv$//;

  return {
    flv => $filename,
    app => "a953/o10",
    rtmp => "rtmp://foratv.fcod.llnwd.net",
    playpath => $playpath,
  };
}

1;
