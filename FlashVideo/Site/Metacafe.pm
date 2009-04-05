# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Metacafe;

use strict;
use URI::Escape;
use URI::Escape;

sub find_video {
  my ($self, $browser) = @_;

  my $url;
  if ($browser->content =~ m'mediaURL=(http.+?)&') {
    $url = uri_unescape($1);
  } else {
    die "Couldn't find mediaURL parameter.";
  }

  if ($browser->content =~ m'gdaKey=(.+?)&') {
    $url .= "?__gda__=" . uri_unescape($1);
  } else {
    die "Couldn't find gdaKey parameter.";
  }

  my $filename;
  if ($browser->content =~ /<title>(.*?)<\/title>/) {
    $filename = title_to_filename($1);
  }
  $filename ||= get_video_filename();

  return ($url, $filename);
}

1;
