# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Fora;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my $has_xml_simple = eval { require XML::Simple };
  if(!$has_xml_simple) {
    die "Must have XML::Simple installed to download Fora videos";
  }

  my($clip_id) = $browser->content =~ /clipid=(\d+)/;
  die "Unable to extract clipid" unless $clip_id;

  $browser->get("http://fora.tv/fora/fora_player_full?cid=$clip_id&h=1&b=0");

  my $xml = eval { XML::Simple::XMLin($browser->content) };
  die "Couldn't parse Fora XML: $@" if $@;

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
