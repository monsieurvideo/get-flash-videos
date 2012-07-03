# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Daum;

use strict;
use FlashVideo::Utils;
use HTML::Entities qw(decode_entities);

sub find_video {
  my ($self, $browser) = @_;

  # Step 1: Get video ID
  my $video_id = get_video_id($browser);
  debug "Video ID: ${video_id}";

  # Step 2: Get video title
  my $video_title = get_video_title($browser, $video_id);
  debug "Video title: ${video_title}";

  # Step 3: Get video URL
  my $video_url = get_video_url($browser, $video_id);
  debug "Video URL: ${video_url}";

  return $video_url, title_to_filename($video_title);
}

# Internal subroutines

sub is_valid_video_id {
  my ($video_id) = @_;

  return if !defined $video_id;

  return if length $video_id != 12 && length $video_id != 23;

  return if length $video_id == 12 && $video_id !~ /\$$/xms;

  return 1;
}

sub get_video_id {
  my ($browser) = @_;

  # http://tvpot.daum.net/best/Top.do?from=gnb#clipid=31946003
  if ( $browser->uri()->as_string() =~ /[#?&] clipid = (\d+)/xmsi ) {
    my $url = 'http://tvpot.daum.net/clip/ClipView.do?clipid=' . $1;
    $browser->get($url);
    die "Cannot fetch '${url}'\n" if !$browser->success();
  }

  my $document = $browser->content();

  # "http://flvs.daum.net/flvPlayer.swf?vid=FlVGvam5dPM$"
  my $flv_player_url = quotemeta 'http://flvs.daum.net/flvPlayer.swf';
  my $video_id_pattern_1 = qr{['"] ${flv_player_url} [?] vid = ([^'"&]+)}xmsi;

  my $func_name;

  # Story.UI.PlayerManager.createViewer('2oHFG_aR9uA$');
  $func_name = quotemeta 'Story.UI.PlayerManager.createViewer';
  my $video_id_pattern_2 = qr{${func_name} [(] ' (.+?) ' [)]}xms;

  # daum.Music.VideoPlayer.add("body_mv_player", "_nACjJ65nKg$",
  $func_name = quotemeta 'daum.Music.VideoPlayer.add';
  my $video_id_pattern_3
      = qr{${func_name} [(] "body_mv_player", \s* " (.+?) " ,}xms;

  # controller/video/viewer/VideoView.html?vid=90-m2tl87zM$&play_loc=...
  my $video_id_pattern_4
      = qr{/video/viewer/VideoView.html [?] vid = (.+?) &}xms;

  if (    $document !~ $video_id_pattern_1
       && $document !~ $video_id_pattern_2
       && $document !~ $video_id_pattern_3
       && $document !~ $video_id_pattern_4 )
  {
    die "Cannot find video ID.\n";
  }
  my $video_id = $1;

  # Remove white spaces in video ID.
  $video_id =~ s/\s+//xmsg;

  die "Invalid video ID: ${video_id}\n" if !is_valid_video_id($video_id);

  return $video_id;
}

sub get_video_title {
  my ($browser, $video_id) = @_;

  my $query_url = "http://tvpot.daum.net/clip/ClipInfoXml.do?vid=${video_id}";
  $browser->get($query_url);
  die "Cannot fetch '${query_url}'.\n" if !$browser->success();
  my $document = $browser->content();

  # <TITLE><![CDATA[Just The Way You Are]]></TITLE>
  my $video_title_pattern
    = qr{<TITLE> <!\[CDATA \[ (.+?) \] \]> </TITLE>}xmsi;
  die "Cannot find video title.\n" if $document !~ $video_title_pattern;
  my $video_title = $1;

  # &amp; => &
  $video_title = decode_entities($video_title);

  return $video_title;
}

sub get_video_url {
  my ($browser, $video_id) = @_;

  my $query_url
      = 'http://videofarm.daum.net/controller/api/open/v1_2/'
      . 'MovieLocation.apixml'
      . "?vid=${video_id}&preset=main";
  $browser->get($query_url);
  die "Cannot fetch '${query_url}'.\n" if !$browser->success();
  my $document = $browser->content();

  # <![CDATA[
  # http://cdn.flvs.daum.net/fms/pos_query2.php?service_id=1001&protocol=...
  # ]]>
  my $url_pattern = qr{<!\[CDATA\[ \s* (.+?) \s* \]\]>}xmsi;
  die "Cannot find URL.\n" if $document !~ $url_pattern;
  my $url = $1;

  my $video_url;

  # http://cdn.flvs.daum.net/fms/pos_query2.php?service_id=1001&protocol=...
  if ( $url =~ /pos_query2[.]php/xms ) {
      $browser->get($url);
      die "Cannot fetch '${url}'.\n" if !$browser->success();
      $document = $browser->content();

      # movieURL="http://stream.tvpot.daum.net/swxwT-/InNM6w/JgEM-E/..."
      my $video_url_pattern = qr{movieURL = " (.+?) "}xmsi;
      die "Cannot find video URL.\n" if $document !~ $video_url_pattern;
      $video_url = $1;
  }
  else {
      $video_url = $url;
  }

  return $video_url;
}

1;
