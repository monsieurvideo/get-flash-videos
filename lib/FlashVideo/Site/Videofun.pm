# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Videofun;

use strict;
use FlashVideo::Utils;
use URI::Escape;

our $VERSION = '0.01';
sub Version() { $VERSION; }

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my $coded_url = "";
  my $url = "";
  my $name = "";


  # read URL from the configuration passed to flash player
  if ($browser->content =~ /\s*{url: "(http[^"]+)".*autoBuffering.*/) {
    $coded_url = $1;
  } else {
    # if we can't get it, just leave as the video URL is there
    return;
  }

  debug ("Coded URL: " . $coded_url);


  $url = uri_unescape($coded_url);
  debug("URL: '" . $url . "'");

  # URL ends with filename
  $name = $url;
  $name =~ s/.*\/([^\/]+)\?.*/$1/;
  return $url, title_to_filename($name);
}

1;
