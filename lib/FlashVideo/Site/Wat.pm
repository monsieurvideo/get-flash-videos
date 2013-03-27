# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Wat;

use strict;
use FlashVideo::Utils;
use HTML::Entities;
use URI::Escape;

our $VERSION = '0.01';
sub Version { $VERSION; }

die "Must have Digest::MD5 for this download\n" 
  unless eval {
    require Digest::MD5;
  };

sub token {
  my ($url, $browser) =  @_;

  $browser->get("http://www.wat.tv/servertime");

  my $hexdate = $browser->content;
  my @timestamp = split('\|', $hexdate);
  $hexdate = sprintf("%x", shift(@timestamp));
  my $key = "9b673b13fa4682ed14c3cfa5af5310274b514c4133e9b3a81e6e3aba00912564";
  return Digest::MD5::md5_hex($key . $url . $hexdate) . "/" . $hexdate;
}


sub find_video {
  my ($self, $browser) = @_;

  $browser->content =~ /url\s*:\s*["'].*?nIc0K11(\d+)["']/i
    || die "No video ID found";
  my $video_id = $1;

  $browser->get("http://www.wat.tv/interface/contentv3/$video_id");

  my $title = json_unescape(($browser->content =~ /title":"(.*?)",/)[0]);

  my $location = "/web/$video_id";
  my $token = &token($location, $browser);

  my $url = "http://www.wat.tv/get".$location.
         "?token=".$token.
         "&context=swf2&getURL=1&version=WIN%2010,3,181,14";

  my $file_type = 'flv';

  # This *looks* like a video URL, but it actually isn't - URL is supplied
  # in the content of the response.
  $browser->head($url);
  
  if (!$browser->success) {
    die "Couldn't do HEAD request $url: " . $browser->response->status_line;
  }

  my $content_type = $browser->response->header('Content-Type');
  if ($content_type =~ /text/) {
    $browser->get($url);

    if (!$browser->success) {
      die "Couldn't get $url: " . $browser->response->status_line;
    }

    if ($browser->content =~ m'^(http://\S+)') {
      $url = $1;

      # Some videos are H264
      if ($url =~ /\.h264/) {
        $file_type = 'mp4';
      }
    }
  }
  else {
    die "Unexpected Content-Type ($content_type) from Wat server."; 
  }

  my $filename = title_to_filename($title, $file_type);

  $browser->allow_redirects;

  return $url, $filename;
}

1;
