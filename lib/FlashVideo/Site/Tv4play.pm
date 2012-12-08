# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Tv4play;
use strict;
use FlashVideo::Utils;
use List::Util qw(reduce);

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;
  my $video_id = ($embed_url =~ /video_id=([0-9]*)/)[0];
  my $smi_url = "http://premium.tv4play.se/api/web/asset/$video_id/play";
  my $title = ($browser->content =~ /property="og:title" content="(.*?)"/)[0];
  my $flv_filename = title_to_filename($title, "flv");

  $browser->get($smi_url);
  my $content = from_xml($browser);
  my $i = 0;
  my @streams;
  my $subtitle_url;

  foreach my $item (@{ $content->{items}->{item} || [] }) {
    push @streams, {
      rtmp    => $item->{base},
      bitrate => $item->{bitrate},
      mp4     => $item->{url},
      format  => $item->{mediaFormat}
    };
  }

  foreach (@streams) {
    if ($_->{format} eq 'smi') {
      $subtitle_url = $_->{mp4};
      last;
    }
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

  my $max_stream = reduce {$a->{bitrate} > $b->{bitrate} ? $a : $b} @streams;

  return {
    rtmp     => $max_stream->{rtmp},
    swfVfy   => "http://www.tv4play.se/flash/tv4playflashlets.swf",
    playpath => $max_stream->{mp4},
    flv      => $flv_filename
  };
}

1;
