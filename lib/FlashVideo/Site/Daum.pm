# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Daum;

use strict;
use FlashVideo::Utils;
use HTML::Entities qw(decode_entities);

sub find_video {
  my ($self, $browser) = @_;

  # Step 1: Get video ID
  my $video_id = get_video_id($browser);
  debug "Video ID: $video_id";

  # Step 2: Get video title
  my $video_title = get_video_title($browser, $video_id);
  debug "Video title: $video_title";

  # Step 3: Get video URL
  my $video_url = get_video_url($browser, $video_id);
  debug "Video URL: $video_url";

  return $video_url, title_to_filename($video_title);
}

sub get_video_id {
  my ($browser) = @_;

  my $document = $browser->content();

  # "http://flvs.daum.net/flvPlayer.swf?vid=FlVGvam5dPM$"
  my $flv_player_url = quotemeta 'http://flvs.daum.net/flvPlayer.swf';
  my $video_id_pattern = qr{" $flv_player_url [?] vid = (.+?) ["&]}xmsi;
  if ( $document !~ $video_id_pattern ) {
    die "Cannot find video ID from the document.\n";
  }
  my $video_id = $1;

  return $video_id;
}

sub get_video_title {
  my ($browser, $video_id) = @_;

  my $query_url = "http://tvpot.daum.net/clip/ClipInfoXml.do?vid=$video_id";

  $browser->get($query_url);
  if ( !$browser->success() ) {
    die 'Cannot fetch the document identified by the given URL: '
      . "$query_url\n";
  }

  my $document = $browser->content();

  # <TITLE><![CDATA[Just The Way You Are]]></TITLE>
  my $video_title_pattern
    = qr{<TITLE> <!\[CDATA \[ (.+?) \] \]> </TITLE>}xmsi;
  if ( $document !~ $video_title_pattern ) {
    die "Cannot find video title from the document.\n";
  }
  my $video_title = $1;

  # &amp; => &
  $video_title = decode_entities($video_title);

  return $video_title;
}

sub get_video_url {
  my ($browser, $video_id) = @_;

  my $query_url
    = 'http://stream.tvpot.daum.net/fms/pos_query2.php'
    . '?service_id=1001&protocol=http&out_type=xml'
    . "&s_idx=$video_id";

  $browser->get($query_url);
  if ( !$browser->success() ) {
    die 'Cannot fetch the document identified by the given URL: '
      . "$query_url\n";
  }

  my $document = $browser->content();

  # movieURL="http://stream.tvpot.daum.net/swxwT-/InNM6w/JgEM-E/OxDQ$$.flv"
  my $video_url_pattern = qr{movieURL = "(.+?)"}xmsi;
  if ( $document !~ $video_url_pattern ) {
    die "Cannot find video URL from the document.\n";
  }
  my $video_url = $1;

  return $video_url;
}

1;
