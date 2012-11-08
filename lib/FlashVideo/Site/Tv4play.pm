# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Tv4play;
use strict;
use FlashVideo::Utils;


sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;
  my $vid = ($embed_url =~ /video_id=([0-9]*)/)[0];
  my $smi_url = "http://premium.tv4play.se/api/web/asset/$vid/play"; 
  my $title = ($browser->content =~ /property="og:title" content="(.*?)"/)[0];
  my $flv_filename = title_to_filename($title, "flv");

  $browser->get($smi_url);
  my $content = from_xml($browser);
  my $i = 0;
  my @streams;
  my $subtitle_url;

  for ($i = 0; $i < length($content->{items}); $i++){
    my $format = $content->{items}->{item}[$i]->{mediaFormat};
    my $bitrate = $content->{items}->{item}[$i]->{bitrate};
    my $rtmp = $content->{items}->{item}[$i]->{base};
    my $mp4 = $content->{items}->{item}[$i]->{url};
    @streams[$i] = { 'rtmp' => $rtmp,
		  'bitrate' => $bitrate,
		  'mp4' => $mp4,
		  'format' => $format
		};
  }

  foreach (@streams) {
    if($_->{format} eq 'smi'){ $subtitle_url = $_->{mp4};}
  }

  if ($prefs->{subtitles} == 1) {
    if (not $subtitle_url eq '') {
      $browser->get("$subtitle_url");
      if (!$browser->success) {
        info "Couldn't download subtitles: " . $browser->status_line;
      } else {
	my $srt_filename = title_to_filename($title, "srt");
	info "Saving subtitles as " . $srt_filename;
	open my $srt_fh, '>', $srt_filename
	  or die "Can't open subtitles file $srt_filename: $!";
	binmode $srt_fh, ':utf8';
	print $srt_fh $browser->content;
	close $srt_fh;
      }
    } else {
      info "No subtitles found";
    }
  }

  return {
      rtmp => $streams[0]->{rtmp},
      swfVfy => "http://www.tv4play.se/flash/tv4playflashlets.swf",
      playpath =>  $streams[0]->{mp4},
      flv => $flv_filename
  };
}

1;
