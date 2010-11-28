# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Xhamster;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser) = @_;

  my $server;
  if ($browser->content =~ m{'srv': '(http://[^'"]+)'}) {
    $server = $1;
  }
  else {
    die "Couldn't determine xhamster server";
  }

  my $video_file;
  if ($browser->content =~ m{'file': '([^'"]+\.flv)'}) {
    $video_file = $1;
  }
  else {
    die "Couldn't determine xhamster video filename";
  }

  my $filename = title_to_filename(extract_title($browser));
 
  my $url = sprintf "%s/flv2/%s", $server, $video_file;

  # I want to follow redirects now
  $browser->allow_redirects;

  return $url, $filename;
}

1;
