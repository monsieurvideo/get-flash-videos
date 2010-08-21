# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Wat;

use strict;
use FlashVideo::Utils;
use HTML::Entities;
use URI::Escape;

sub find_video {
  my ($self, $browser) = @_;

  $browser->content =~ /videoid\s*:\s*["'](\d+)/i
    || die "No video ID found";
  my $video_id = $1;

  $browser->get("http://www.wat.tv/interface/contentv2/$video_id");

  my $title = json_unescape(($browser->content =~ /title":"(.*?)",/)[0]);
  my $url   = json_unescape(($browser->content =~ /files.*?url":"(.*?)",/)[0]);

  # Need to supply some other parameters
  $url .= "?context=swf2&getURL=1&version=WIN%2010,0,45,2";

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
