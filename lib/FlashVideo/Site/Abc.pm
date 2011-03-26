# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Abc;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  # Clips are handled differently to full episodes
  if ($browser->uri->as_string =~ m'/watch/clip/[\w\-]+/(\w+)/(\w+)/(\w+)') {
    my $show_id     = $1;
    my $playlist_id = $2;
    my $video_id    = $3;

    return handle_abc_clip($browser, $show_id, $playlist_id, $video_id);
  }

  my $playpath;
  if ($browser->content =~ /http:\/\/cdn\.video\.abc\.com\/abcvideo\/video_fep\/thumbnails\/220x124\/([^"]*)220x124\.jpg/) {
    $playpath = "mp4:/abcvideo/video_fep/mov/" . lc($1) . "768x432_700.mov";
  }
  
  $browser->content =~ /<h2 id="video_title">([^<]*)<\/h2>/;
  my $title = $1;
  my $rtmpurl = "rtmp://abcondemandfs.fplive.net:1935/abcondemand";

  return {
    rtmp => $rtmpurl,
    playpath => $playpath,
    flv => title_to_filename($title)
  };
}

sub handle_abc_clip {
  my ($browser, $show_id, $playlist_id, $video_id) = @_;

  # Note 'limit' has been changed to 1 instead of the default of 12. This
  # ensures that only the desired video is returned. Otherwise unrelated
  # videos are returned too.

  my $abc_clip_rss_url_template =
    "http://ll.static.abc.com/vp2/ws/s/contents/1000/videomrss?" .
    "brand=001&device=001&width=644&height=362&clipId=%s" .
    "&start=0&limit=1&fk=CATEGORIES&fv=%s";
  
  my $abc_clip_rss_url = sprintf $abc_clip_rss_url_template,
                                 $video_id, $playlist_id;

  $browser->get($abc_clip_rss_url);

  if (!$browser->success) {
    die "Couldn't download ABC clip RSS: " . $browser->response->status_line;
  }

  my $xml = from_xml($browser);

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

  if (ref($category) eq 'HASH' and ! keys %$category) {
    $category = '';
  }

  # Description isn't actually very long - see media:text for that for when
  # gfv has support for writing Dublin Core-compliant metadata.
  my $description = $xml->{channel}->{item}->{'media:description'}->{content};

  # Remove HTML in evil way.
  for ($category, $description, $title) {
    s/<\/?\w+>//g;
  }

  my $video_title = make_title($category, $episode_name, $title, $description);

  return $video_url, title_to_filename($video_title, $type);
}

# Produces the title, taking into account items that don't exist
sub make_title {
  return join " - ", grep /./, @_;
}

sub can_handle {
  my($self, $browser, $url) = @_;

  # This is only ABC as in the US broadcaster, not abc.net.au
  return $url && URI->new($url)->host =~ /\babc\.(?:go\.)?com$/;
}

1;
