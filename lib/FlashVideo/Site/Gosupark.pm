# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Gosupark;

use strict;
use FlashVideo::Utils;

our $VERSION = '0.01';
sub Version() { $VERSION; }

sub find_video {
  my ($self, $browser, $embed_url) = @_;
  my $url = "";

  if ($browser->content =~ /.*\s*file: "(http:\/\/gosupark[^"]+).*",/) {
    $url = $1;
  } else {
    return;
  }
  debug ("URL: '" . $url . "'");
  return $url, title_to_filename("", "mp4");
}

1;

