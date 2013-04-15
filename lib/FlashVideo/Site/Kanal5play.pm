# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Kanal5play;

use strict;
use warnings;
use FlashVideo::Utils;
use FlashVideo::JSON;

our $VERSION = '0.02';
sub Version() { $VERSION;}

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;
  if (!($browser->uri->as_string =~ m/video\/([0-9]*)/)) {
    die "No video id found in url";
  }
  my $video_id = $1;
  my $info_url = "http://www.kanal5play.se/api/getVideo?format=FLASH&videoId=$video_id";
  $browser->get($info_url);

  if (!$browser->success) {
    die "Couldn't download $info_url: " . $browser->response->status_line;
  }

  my $jsonstr  = $browser->content;
  my $json     = from_json($jsonstr);

  my $name     = $json->{program}->{name};
  my $episode  = $json->{episodeNumber};
  my $season   = $json->{seasonNumber};
  my $filename = sprintf "%s - S%02dE%02d", $name, $season, $episode;
  my $rtmp     = "rtmp://fl1.c00608.cdn.qbrick.com:1935/00608";
  my $playpath = $json->{streams}[0]->{source};
  my $max_rate = 0;

  # Always take the highest bitrate stream
  foreach my $stream (@{$json->{streams}}) {
    my $rate = int($stream->{bitrate});
    if ($rate > $max_rate) {
      $playpath = $stream->{source};
      $max_rate = $rate;
    }
  }

  # Check if the maximum quality stream is available.
  # The stream is not present in the json object even if it exists,
  # so we have to try the playpath manually.
  my $downloader = FlashVideo::RTMPDownloader->new;
  $playpath =~ m/(.*)_([0-9]*)\Z/;
  my $playpath_max = $1 . "_1600";

  my $args = {
    flv      => title_to_filename($filename, "flv"),
    rtmp     => $rtmp,
    playpath => $playpath_max,
    swfVfy   => "http://www.kanal5play.se/flash/K5StandardPlayer.swf"
  };

  # If the stream was not found we revert the playpath
  if (!$downloader->try_download($args)) {
    $args->{playpath} = $playpath;
  }

  return $args;
}
1;
