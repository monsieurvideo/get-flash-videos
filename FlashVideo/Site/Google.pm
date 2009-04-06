# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Google;

use strict;
use FlashVideo::Utils;
use URI::Escape;

sub find_video {
  my ($self, $browser) = @_;

  if (!$browser->success) {
    $browser->get($browser->response->header('Location'));
    die "Couldn't download URL: " . $browser->response->status_line
      unless $browser->success;
  }

  my $url;
  if ($browser->content =~ /googleplayer\.swf\?&?videoUrl(.+?)\\x26/) {
    $url = uri_unescape($1);

    # Contains JavaScript (presumably) escaping \xHEX, so unescape hackily
    $url =~ s/\\x([A-F0-9]{2})/chr(hex $1)/egi;
    $url =~ s/^=//;
  }

  my $filename;
  if ($browser->content =~ /<title>(.*?)<\/title>/) {
    $filename = title_to_filename($1);
  }
  $filename ||= get_video_filename();

  return ($url, $filename);
}

1;
