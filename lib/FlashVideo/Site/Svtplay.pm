# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Svtplay;

use strict;
use warnings;

use FlashVideo::Utils;
use FlashVideo::JSON;

our $VERSION = '0.06';
sub Version() { $VERSION;}

sub find_video_svt {
  my ($self, $browser, $embed_url, $prefs, $oppet_arkiv) = @_;
  my @rtmpdump_commands;

  if ($browser->uri->as_string !~ m/(video|klipp)\/([0-9]*)/) {
    die "No video id found in url";
  }
  my $vid_type = $1;
  my $video_id = $2;
  my $name = extract_title($browser);
  my $info_url = $oppet_arkiv ?
                 "http://www.oppetarkiv.se/video/$video_id?output=json" :
                 "http://www.svtplay.se/$vid_type/$video_id?output=json" ;
  $browser->allow_redirects;
  $browser->get($info_url);

  if (!$browser->success) {
    die "Couldn't download $info_url: " . $browser->response->status_line;
  }

  $browser->content =~ /(?<=root\[\"__svtplay\"\] = )(.*)/;
  my $jsonstr = $1;
  my $video_data = from_json($jsonstr);
  my $bitrate = -1;
  my $rtmp_url;
  my $m3u8 = "";

  foreach my $video (@{ $video_data->{context}->{dispatcher}->{stores}->{VideoTitlePageStore}->{data}->{video}->{videoReferences} }) {
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
    if (my $subtitles_url = $video_data->{context}->{dispatcher}->{stores}->{VideoTitlePageStore}->{data}->{video}->{subtitles}[1]->{url}) {
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
    my $filename = title_to_filename($name, "mp4");

    return {
      downloader => "hls",
      flv        => $filename,
      args       => { hls_url => $m3u8, prefs => $prefs }
    }

  } else {
    return {
      flv    => title_to_filename($name, "flv"),
      rtmp   => $rtmp_url,
      swfVfy => "http://www.svtplay.se/public/swf/video/svtplayer-2012.15.swf",
    };
  }
}

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;
  $self->find_video_svt($browser, $embed_url, $prefs, 0);
}

1;
