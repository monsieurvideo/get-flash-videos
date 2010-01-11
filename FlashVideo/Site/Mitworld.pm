# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Mitworld;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser) = @_;

  my($title) = $browser->content =~ m{id="video-meta">\s*<h2>(.*?)</h2>}s;
  if(!$title) {
    $title = extract_title($browser);
    $title =~ s/\|.*//;
  }

  my($host) = $browser->content =~ m{host:\s*"(.*?)"};
  my($flv) = $browser->content =~ m{flv:\s*"(.*?)"};

  return {
    rtmp => "rtmp://$host/ondemand/ampsflash/$flv?_fcs_vhost=$host",
    flv  => title_to_filename($title)
  };
}

1;
