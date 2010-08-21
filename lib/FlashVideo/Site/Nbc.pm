# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Nbc;

use strict;
use FlashVideo::Utils;
use MIME::Base64;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my $has_amf_packet = eval { require Data::AMF::Packet };
  if (!$has_amf_packet) {
    die "Must have Data::AMF::Packet installed to download Nbc videos";
  }

  # http://www.nbc.com/30-rock/video/mothers-day/1225683/

  my $video_id;
  if ($browser->uri->as_string =~ /\/([0-9]+)\//) {
    $video_id = $1;
  }

  # no decode base16?
  # 0000000000010016676574436C6970496E666F2E676574436C6970416C6C00022F310000001F0A000000040200073132323631303302000255530200033633320200022D31
  my $packet = Data::AMF::Packet->deserialize(decode_base64("AAAAAAABABZnZXRDbGlwSW5mby5nZXRDbGlwQWxsAAIvMQAAAB8KAAAABAIABzEyMjc2MTECAAJVUwIAAzYzMgIAAi0xCg=="));

  $packet->messages->[0]->{value}->[0] = $video_id;
  #$packet->messages->[0]->{value}->[1] = "US";
  #$packet->messages->[0]->{value}->[2] = "632";
  #$packet->messages->[0]->{value}->[3] = "-1";

  if($::opt{debug}) {
    require Data::Dumper;
    debug Data::Dumper::Dumper($packet);
  }

  my $data = $packet->serialize;

  $browser->post(
    "http://video.nbcuni.com/amfphp/gateway.php",
    Content_Type => "application/x-amf",
    Content => $data
  );

  die "Failed to post to Nbc AMF gateway"
    unless $browser->response->is_success;

  if($::opt{debug}) {
    debug $browser->content;
  }

  # AMF fails so just regex for now

  my($clipurl) = $browser->content =~ /clipurl.{3,5}(nbcrewind[^\0]+)/;

  my($title) = $browser->content =~ /headline.{1,3}([^\0]+)/;

  if($::opt{debug}) {
    debug "$clipurl\n";
    debug "$title\n";
  }

  #$browser->content =~ s/............//;

  #$packet = Data::AMF::Packet->deserialize($browser->content);

  #if($::opt{debug}) {
  #  require Data::Dumper;
  #  debug Data::Dumper::Dumper($packet);
  #}

  #my $clipurl = $packet->messages->[0]->{value}->{clipurl};

  $browser->get("http://video.nbcuni.com/$clipurl");
  my $xml = from_xml($browser);
  my $video_path = $xml->{body}->{switch}->{ref}->{src};

  $browser->get("http://videoservices.nbcuni.com/player/config?configId=17010&clear=true"); # I don't know what configId means but it seems to be generic
  my $xml = from_xml($browser);
  my $app = $xml->{akamaiAppName};
  my $host = $xml->{akamaiHostName};

  $browser->get("http://$host/fcs/ident");
  my $xml = from_xml($browser);
  my $ip = $xml->{ip};
  my $port = "1935";

  my $rtmpurl = "rtmp://$ip:$port/$app/$video_path";

  return {
    rtmp => $rtmpurl,
    swfUrl => "http://www.nbc.com/[[IMPORT]]/video.nbcuni.com/outlet/extensions/inext_video_player/video_player_extension.swf?4.5.3",
    tcUrl => "rtmp://$ip:$port/$app?_fcs_vhost=$host", 
    flv => title_to_filename($title)
  };
}

1;
