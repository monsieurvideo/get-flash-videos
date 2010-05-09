# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Abc;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my $has_xml_simple = eval { require XML::Simple };
  if(!$has_xml_simple) {
    die "Must have XML::Simple installed to download Abc videos";
  }

  #http://abc.go.com/watch/lost/93372/260004/the-candidate
  my $video_id;
  if ($browser->uri->as_string =~ /\/watch\/[^\/]*\/[0-9]*\/([0-9]*)/) {
    $video_id = $1;
  }

  # h is probably quality
  my $quality="432";
  #my $bitrate="1000";

  $browser->get("http://ll.static.abc.com/s/videoplatform/services/1001/getflashvideo?video=$video_id&h=$quality");

  my $xml = XML::Simple::XMLin($browser->content, KeyAttr => []);

  # find a host, we'll default to L3 for now
  my $hosts = $xml->{resources}->{host};
  my $host = ref $hosts eq 'ARRAY' ?
    (grep { $_->{name} == 'L3' } @$hosts)[0] :
    $hosts;

  my $rtmpurl = $xml->{protocol} . "://" . $host->{url} . "/" . $host->{app};

  my $videos = $xml->{videos}->{video};
  my $video = ref $videos eq 'ARRAY' ?
    #(grep { $_->{bitrate} == $bitrate } @$videos)[0] :
    (grep { $_->{src} =~ /^mp4:\// } @$videos)[0] :
    $videos;

  my $playpath = $video->{src};

  $browser->get("http://ll.static.abc.com/s/videoplatform/services/1000/getVideoDetails?video=$video_id");
  my $xml = XML::Simple::XMLin($browser->content);
  my $filename = $xml->{metadata}->{title} . ".flv";

  return {
    rtmp => $rtmpurl,
    playpath => $playpath,
    flv => $filename
  };
}

1;
