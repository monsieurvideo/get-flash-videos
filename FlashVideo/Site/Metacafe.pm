# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Metacafe;

use strict;
use FlashVideo::Utils;
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
    # They're now using a session ID on the end of the URL like this:
    # ?aksessionid=1255084734240_230066
    # but it doesn't seem to actually be required.
  }

  my $filename = title_to_filename(extract_title($browser));

  return ($url, $filename);
}

1;
