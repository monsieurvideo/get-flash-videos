# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Svtplay;
use strict;
use warnings;
use FlashVideo::Utils;
use FlashVideo::JSON;

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;
  my @rtmpdump_commands;
    
  if (!($browser->uri->as_string =~ m/video\/([0-9]*)/)) {
    die "No video id found in url";
  }

  my ($video_id) = $1;
  my $info_url = "http://www.svtplay.se/video/$video_id?output=json";
  $browser->get($info_url);
    
  if (!$browser->success) {
    die "Couldn't download $info_url: " . $browser->response->status_line;
  }

  my $jsonstr = $browser->content;
  my $json = from_json($jsonstr);
  my $name = $json->{context}->{title};
  my ($bitrate) = 0;
  my $rtmp;
  my $i;
  foreach $i (keys $json->{video}->{videoReferences}) {
    my ($rate) = int($json->{video}->{videoReferences}[$i]->{bitrate});
    if ($bitrate < $rate) {
      $rtmp = $json->{video}->{videoReferences}[$i]->{url};
      $bitrate = $rate;
    }
  }

  if ($prefs->{subtitles} == 1) {
    my $sub = $json->{video}->{subtitleReferences}[0]->{url}; 
    if ($sub) {
      info "Found subtitles: " . $sub;
      $browser->get("$sub");
      my $srt_filename = title_to_filename($name, "srt"); 
      my $srt_content = $browser->content;
      open (SRT, '>>',$srt_filename) 
	or die "Can't open subtitles file $srt_filename: $!";
      binmode SRT, ':utf8';
      print SRT $srt_content;
      close SRT;
    } else {
      info "No subtitles found!";
    }
  }
  return {
	  flv => title_to_filename($name, "flv"),
	  rtmp => $rtmp,
	  swfVfy => "http://www.svtplay.se/public/swf/video/svtplayer-2012.15.swf"
	 };
}

1;
