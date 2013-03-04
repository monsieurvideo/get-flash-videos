# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Svtplay;

use strict;
use warnings;

use FlashVideo::Utils;
use FlashVideo::JSON;
use HTML::Entities;

our $VERSION = '0.01';
sub Version() { $VERSION;}

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;
  my @rtmpdump_commands;

  if ($browser->uri->as_string !~ m/video\/([0-9]*)/) {
    die "No video id found in url";
  }
  my $video_id = $1;
  $browser->content =~ m/<title>(.+)<\/title>/;
  my $name = decode_entities($1);
  my $info_url = "http://www.svtplay.se/video/$video_id?output=json";
  $browser->get($info_url);

  if (!$browser->success) {
    die "Couldn't download $info_url: " . $browser->response->status_line;
  }

  my $video_data = from_json($browser->content);
  my $bitrate = -1;
  my $rtmp_url;
  my $m3u8 = "";

  foreach my $video (@{ $video_data->{video}->{videoReferences} }) {
    my $rate = int $video->{bitrate};

    if ($bitrate < $rate && $video->{playerType} eq "flash") {
      $rtmp_url = $video->{url};
      $bitrate = $rate;
    }
    if ($video->{url} =~ /.*\.m3u8/) {
      $m3u8 = $video->{url};
    }
  }

  if ($prefs->{subtitles}) {
    if (my $subtitles_url = $video_data->{video}->{subtitleReferences}[0]->{url}) {
      info "Found subtitles URL: $subtitles_url";

      $browser->get($subtitles_url);

      if (!$browser->success) {
        info "Couldn't download subtitles: " . $browser->status_line;
      }

      my $srt_filename = title_to_filename($name, "srt");

      open my $srt_fh, '>', $srt_filename
        or die "Can't open subtitles file $srt_filename: $!";
      binmode $srt_fh, ':utf8';
      print $srt_fh $browser->content;
      close $srt_fh;
    }
    else {
      info "No subtitles found!";
    }
  }

  # If we found an m3u8 file we generate the ffmpeg download command
  if (!($m3u8 eq "")) {
      $browser->get($m3u8);
      if (!$browser->success) {
          die "Couldn't download $m3u8: " . $browser->response->status_line;
      }

      my @lines = split(/\r?\n/, $browser->content);
      $bitrate = -1;
      my $video_url = "";
      my $i = 0;

      # Select highest bitrate available
      foreach my $line (@lines) {
        if ($line =~ /BANDWIDTH/) {
          $line =~ /BANDWIDTH=([0-9]*),/;
          my $this_rate = $1;

          if ($bitrate < $this_rate) {
            $video_url = $lines[$i + 1];
            $bitrate = $this_rate;
          }
        }
        $i++;
      }

      my $filename = title_to_filename($name, "mp4");

      # Set the arguments for ffmpeg
      my @ffmpeg_args = (
        "-i", "$video_url",
        "-acodec", "copy",
        "-vcodec", "copy",
        "-absf", "aac_adtstoasc",
        "-f", "mp4",
        "$filename"
      );

      return {
        downloader => "ffmpeg",
        file       => $filename,
        args       => \@ffmpeg_args
      };
  } else {
    return {
      flv    => title_to_filename($name, "flv"),
      rtmp   => $rtmp_url,
      swfVfy => "http://www.svtplay.se/public/swf/video/svtplayer-2012.15.swf",
    };
  }
}

1;
