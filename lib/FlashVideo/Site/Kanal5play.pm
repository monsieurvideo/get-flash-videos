# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Kanal5play;

use lib 'lib';
use strict;
use warnings;
use FlashVideo::Utils;

my $bitrates = {
     "low" => 250000,
     "medium" => 450000, 
     "high" => 900000 };

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;
  if(!($browser->uri->as_string =~ m/video\/([0-9]*)/)){
      die "No video id found in url";
  }
  my ($video_id) = $1;
  my $info_url = "http://www.kanal5play.se/api/getVideo?format=FLASH&videoId=$video_id";
  $browser->get($info_url);
  if (!$browser->success){
      die "Couldn't download $info_url: " . $browser->response->status_line;
  }
  my $name = ($browser->content =~ /"name":"(.*?)"/)[0];
  my $episode = ($browser->content =~ /"episodeNumber":([0-9]*)/)[0];
  my $season = ($browser->content =~ /"seasonNumber":([0-9]*)/)[0];
  my $filename = "$name - S" . ($season < 10 ? "0" : "") . $season  . 
                 "E" . ($episode < 10 ? "0" : "") . $episode;
  my ($rtmp) = "rtmp://fl1.c00608.cdn.qbrick.com:1935/00608";
  
  my @rate_path;
  my $count;
  my ($temp_text) = $browser->content;
  for ($count = 0; $count < 3; $count++){
      $temp_text =~ /"bitrate":([0-9]*)(.*?)"source":"(.*?)"(.*)/;
      $rate_path[$count] = { 'bitrate' => $1,
			     'mp4'     => $3 };
      $temp_text = $4;
  }
  
  my ($playpath) = $rate_path[0]->{mp4};
  foreach (@rate_path) {
    my ($rate) = int($_->{bitrate});
    if($bitrates->{$prefs->{quality}} == $rate){
        $playpath = $_->{mp4};
    }
  };

  return {
      flv => title_to_filename($filename, "flv"),
      rtmp => $rtmp,
      playpath => $playpath,
      swfVfy => "http://www.kanal5play.se/flash/StandardPlayer.swf"
  };

}
1;
