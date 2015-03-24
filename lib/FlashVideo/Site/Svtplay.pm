# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Svtplay;

use strict;
use warnings;

use FlashVideo::Utils;
use FlashVideo::JSON;
use HTML::Entities;

our $VERSION = '0.04';
sub Version() { $VERSION;}

my $bitrate_index = {
  high   => 0,
  medium => 1,
  low    => 2
};

sub find_video_svt {
  my ($self, $browser, $embed_url, $prefs, $oppet_arkiv) = @_;
  my @rtmpdump_commands;

  if ($browser->uri->as_string !~ m/(video|klipp)\/([0-9]*)/) {
    die "No video id found in url";
  }
  my $vid_type = $1;
  my $video_id = $2;
  $browser->content =~ m/<title>(.+)<\/title>/;
  my $name = decode_entities($1);
  my $info_url = $oppet_arkiv ?
                 "http://www.oppetarkiv.se/video/$video_id?output=json" :
                 "http://www.svtplay.se/$vid_type/$video_id?output=json" ;
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

    my %urls = read_hls_playlist($browser, $m3u8);

    # Sort the urls and select the suitable one based upon quality preference
    my $quality = $bitrate_index->{$prefs->{quality}};
    my $min = $quality < scalar(keys(%urls)) ? $quality : scalar(keys(%urls));
    my $key = (sort {int($b) <=> int($a)} keys %urls)[$min];

    my $video_url = $urls{$key};
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
      flv        => $filename,
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

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;
  $self->find_video_svt($browser, $embed_url, $prefs, 0);
}

1;
