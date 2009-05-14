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

  my $title = json_escape(($browser->content =~ /title":"(.*?)",/)[0]);
  my $url   = json_escape(($browser->content =~ /files.*?url":"(.*?)",/)[0]);

  my $filename = title_to_filename($title);

  $browser->allow_redirects;

  return $url, $filename;
}

# Maybe should use a proper JSON parser, but want to avoid the dependency for now..
sub json_escape {
  my($s) = @_;

  $s =~ s/\\u([0-9a-f]{1,4})/chr hex $1/eg;
  $s =~ s/\\//g;

  return $s;
}

1;
