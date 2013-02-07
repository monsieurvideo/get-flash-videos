# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Kanal5play;

use strict;
use warnings;
use FlashVideo::Utils;
use FlashVideo::JSON;


my $bitrates = {
  low    => 250000,
  medium => 450000,
  high   => 900000
};

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

  my $jsonstr = $browser->content;
  my $json = from_json($jsonstr);

  my $name = $json->{program}->{name};
  my $episode = $json->{episodeNumber};
  my $season = $json->{seasonNumber};
  my $filename = sprintf "%s - S%02dE%02d", $name, $season, $episode;
  my $rtmp = "rtmp://fl1.c00608.cdn.qbrick.com:1935/00608";
  my $playpath = $json->{streams}[0]->{source};

  while (my ($key, $stream) = each($json->{streams})) {
    my $rate = int($stream->{bitrate});
    if ($bitrates->{$prefs->{quality}} == $rate) {
      $playpath = $stream->{source};
      last;
    }
  }

  return {
    flv      => title_to_filename($filename, "flv"),
    rtmp     => $rtmp,
    playpath => $playpath,
    swfVfy   => "http://www.kanal5play.se/flash/K5StandardPlayer.swf"
  };
}
1;
