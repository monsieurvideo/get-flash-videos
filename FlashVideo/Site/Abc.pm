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

  # Clips are handled differently to full episodes
  if ($browser->uri->as_string =~ m'/watch/clip/[\w\-]+/(\w+)/(\d+)/(\d+)') {
    my $show_id     = $1;
    my $playlist_id = $2;
    my $video_id    = $3;

    return handle_abc_clip($browser, $show_id, $playlist_id, $video_id);
  }

  # http://abc.go.com/watch/lost/93372/260004/the-candidate
  my $video_id;
  if ($browser->uri->as_string =~ /\/watch\/[^\/]*\/[0-9]*\/([0-9]*)/) {
    $video_id = $1;
  }

  # h is probably quality
  my $quality="432";

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

sub handle_abc_clip {
  my ($browser, $show_id, $playlist_id, $video_id) = @_;

  # Note 'limit' has been changed to 1 instead of the default of 12. This
  # ensures that only the desired video is returned. Otherwise unrelated
  # videos are returned too.
  my $abc_clip_rss_url_template =
    "http://a.abc.com/rss/videoMrss?&width=644&height=362&" .
    "showKey=%s&clipId=%d&start=0&limit=1&fk=CATEGORIES&fv=%d";
  
  my $abc_clip_rss_url = sprintf $abc_clip_rss_url_template, $show_id,
                                 $video_id, $playlist_id;

  $browser->get($abc_clip_rss_url);

  if (!$browser->success) {
    die "Couldn't download ABC clip RSS: " . $browser->response->status_line;
  }

  my $xml = eval { XML::Simple::XMLin($browser->content) };

  if ($@) {
    die "Couldn't parse ABC clip RSS XML: $@";
  }

  my $video_url = $xml->{channel}->{item}->{'media:content'}->{url};
  my $type      = $video_url =~ /\.mp4$/ ? 'mp4' : 'flv';

  if (!$video_url) {
    die "Couldn't determine ABC clip URL";
  }

  # Try to get a decent filename
  my $episode_name;
  if ($video_url =~ /FLF_\d+[A-Za-z]{0,5}_([^_]+)/) {
    $episode_name = $1;
  }

  my $category    = $xml->{channel}->{item}->{category};
  my $title       = $xml->{channel}->{item}->{'media:title'}->{content};

  # Description isn't actually very long - see media:text for that for when
  # gfv has support for writing Dublin Core-compliant metadata.
  my $description = $xml->{channel}->{item}->{'media:description'}->{content};

  # Remove HTML in evil way.
  for ($category, $description, $title) {
    s/<\/?\w+>//g;
  }

  my $video_title = $episode_name ?
    "$category - $episode_name - $title - $description" :
    "$category - $title - $description";

  return $video_url, title_to_filename($video_title, $type);
}

sub can_handle {
  my($self, $browser, $url) = @_;

  # This is only ABC as in the US broadcaster, not abc.net.au
  return $url && URI->new($url)->host =~ /\babc\.(?:go\.)?com$/;
}

1;
