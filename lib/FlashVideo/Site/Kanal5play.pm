# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Kanal5play;

use strict;
use warnings;
use FlashVideo::Utils;
use FlashVideo::JSON;

our $VERSION = '0.04';
sub Version() { $VERSION;}

my $bitrate_index = {
  high   => 0,
  medium => 1,
  low    => 2
};

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;
  if (!($browser->uri->as_string =~ m/video\/([0-9]*)/)) {
    die "No video id found in url";
  }
  my $video_id = $1;
  my $info_url = "http://www.kanal5play.se/api/getVideo?format=IPAD&videoId=$video_id";

  $browser->get($info_url);

  if (!$browser->success) {
    die "Couldn't download $info_url: " . $browser->response->status_line;
  }

  my $jsonstr  = $browser->content;
  my $json     = from_json($jsonstr);
  my $name     = $json->{program}->{name};
  my $episode  = $json->{episodeNumber};
  my $season   = $json->{seasonNumber};
  my $subtitle = $json->{hasSubtitle};
  my $filename = sprintf "%s - S%02dE%02d", $name, $season, $episode;
  my $hls_m3u  = $json->{streams}[0]->{source};

  my %paths = read_hls_playlist($browser, $hls_m3u);

  # Sort the paths and select the suitable one based upon quality preference
  my $quality = $bitrate_index->{$prefs->{quality}};
  my $min = $quality < scalar(keys(%paths)) ? $quality : scalar(keys(%paths));
  my $key = (sort {int($b) <=> int($a)} keys %paths)[$min];

  my $video_url = $paths{$key};

  my $hls_base = $hls_m3u;
  $hls_base =~ s/playlist\.m3u8//;

  $filename = title_to_filename($filename, "mp4");

  # Set the arguments for ffmpeg
  my @ffmpeg_args = (
    "-i", "$hls_base$video_url",
    "-acodec", "copy",
    "-vcodec", "copy",
    "-absf", "aac_adtstoasc",
    "-f", "mp4",
    "$filename"
  );

  # Check for subtitles
  if ($prefs->{subtitles} and $subtitle) {
    my $subtitle_url = "http://www.kanal5play.se/api/subtitles/$video_id";
    $browser->get($subtitle_url);
    if (!$browser->success) {
      die "Couldn't download $subtitle_url: " . $browser->response->status_line;
    }
    $jsonstr = $browser->content;
    $json = from_json($jsonstr);

    # The format is a list of hashmap with the following keys:
    # startMillis : int
    # endMillis : int
    # text : string
    # posX : int
    # posY : int
    # colorR : int
    # colorG : int
    # colorB : int
    #
    # We convert this to an srt

    my $srt_filename = title_to_filename($filename, "srt");
    open my $srt_fh, '>', $srt_filename
      or die "Can't open subtitles file $srt_filename: $!";

    my $i = 1;

    foreach my $line (@{$json}) {
      my $text  = $line->{text};
      my $hour  = int($line->{startMillis}) / 3600000;
      my $min   = (int($line->{startMillis}) / 60000) % 60;
      my $sec   = (int($line->{startMillis}) / 1000) % 60;
      my $milli = int($line->{startMillis}) % 1000;

      my $start = sprintf "%02d:%02d:%02d,%03d", $hour, $min, $sec, $milli;

      $hour  = int($line->{endMillis}) / 3600000;
      $min   = (int($line->{endMillis}) / 60000) % 60;
      $sec   = (int($line->{endMillis}) / 1000) % 60;
      $milli = int($line->{endMillis}) % 1000;

      my $end = sprintf "%02d:%02d:%02d,%03d", $hour, $min, $sec, $milli;

      print $srt_fh "$i\n" . "$start --> $end\n" . "$text\n\n";

      $i++;
    }
    close $srt_fh;
  }

  return {
    downloader => "ffmpeg",
    flv        => $filename,
    args       => \@ffmpeg_args
  };
}
1;
