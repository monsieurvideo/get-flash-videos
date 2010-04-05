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

  my $filename = title_to_filename($title);

  $browser->allow_redirects;

  return $url, $filename;
}

1;
