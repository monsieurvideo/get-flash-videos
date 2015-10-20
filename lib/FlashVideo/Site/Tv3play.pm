# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Tv3play;
use strict;
use warnings;
use FlashVideo::Utils;
use FlashVideo::JSON;
our $VERSION = '0.06';
sub Version() { $VERSION;}

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;
  return $self->find_video_viasat($browser,$embed_url,$prefs);
}

sub find_video_viasat {
  my ($self, $browser, $embed_url, $prefs) = @_;

  my $bitrate_index = {
    high   => 0,
    medium => 1,
    low    => 2
  };

  my $video_id = ($browser->content =~ /data-video-id="([0-9]*)"/)[0];
  info "Got video_id: $video_id";
  my $info_url = "http://playapi.mtgx.tv/v3/videos/$video_id";
  my $stream_url = "http://playapi.mtgx.tv/v3/videos/stream/$video_id";
  $browser->get($info_url);

  my $json = from_json($browser->content);
  my $title = $json->{title};

  if ($prefs->{subtitles}) {
    my $sub_url = "";

    if (exists $json->{sami_path}) {
      $sub_url = $json->{sami_path};
    } elsif (exists $json->{subtitles_for_hearing_impaired}) {
      $sub_url = $json->{subtitles_for_hearing_impaired};
    }

    if ($sub_url ne "") {
      my $srt_name = title_to_filename($title, "srt");
      $browser->get($sub_url);
      convert_dc_subtitles_to_srt($browser, $srt_name);
    } else {
      info "No subtitles found!";
    }
  }

  $browser->get($stream_url);
  $json = from_json($browser->content);

  # Prefer hls stream since it contains better video format
  if ($json->{streams}->{hls}) {
    my $hls_url = $json->{streams}->{hls};

    my %urls = read_hls_playlist($browser, $hls_url);

    #  Sort the urls and select the suitable one based upon quality preference
    my $quality = $bitrate_index->{$prefs->{quality}};
    my $min = $quality < scalar(keys(%urls)) ? $quality : scalar(keys(%urls));
    my $key = (sort {int($b) <=> int($a)} keys %urls)[$min];

    my ($hls_base, $trail) = ($hls_url =~ m/(.*\/)(.*)\.m3u8/);
    my $filename = title_to_filename($title, "mp4");
    my $video_url = $urls{$key} =~ m/http:\/\// ? $urls{$key} : $hls_base.$urls{$key};

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
  }

  # Fallback to rtmp stream if hls not available
  my $filename = title_to_filename($title, "flv");

  my $rtmp_med = $json->{streams}->{medium};

  my $rtmp_data = {
    'rtmp'   => $rtmp_med,
    'swfVfy' => "http://flvplayer.viastream.viasat.tv/flvplayer/play/swf/MTGXPlayer-2.0.6.swf",
    'flv'    => $filename
  };

  return $rtmp_data;
}

1;
