# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Video44;

use strict;
use FlashVideo::Utils;
use URI::Escape;

our $VERSION = '0.01';
sub Version() { $VERSION; }

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my $flashvars = "";
  my $file = "";
  my $url = "";
  my $name = "";

  # get configuration passed to flash player
  if ($browser->content =~ /\s*<param name="flashvars"\s*value="([^"]+)" \/>/) {
    $flashvars = $1;
  } else {
    # if we can't get it, just leave as the video URL is there
    debug("Can't find flashvars");
    return;
  }

  debug ("Flashvars: " . $flashvars);

  # in the configuration there is also URL we're looking for
  if ($flashvars =~ /&amp;file=(http[^&]+)&amp;/) {
    $file = $1;
  } else {
    debug("Can't find file");
    return;
  }

  debug("File: " . $file);

  $url = uri_unescape($file);
  debug("URL: '" . $url . "'");

  # URL ends with filename
  $name = $url;
  $name =~ s/.*\/([^\/]+)/$1/;
  return $url, title_to_filename($name);
}

1;
