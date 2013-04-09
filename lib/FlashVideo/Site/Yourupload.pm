# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Yourupload;

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

  if ($embed_url !~ /http:\/\/yourupload.com\/embed\//) {
    if ($browser->content =~ /<iframe src="(http:\/\/yourupload.com\/embed\/[^"]+)" style/) {
      $embed_url = $1;
      $browser->get($embed_url);
    } else {
      # we can't find the frame with embed URL
      return;
    }
  }

  # get configuration passed to flash player
  if ($browser->content =~ /\s*flashvars="([^"]+)"/) {
    $flashvars = $1;
  } else {
    # if we can't get it, just leave as the video URL is there
    debug("Can't find flashvars");
    return;
  }

  debug ("Flashvars: " . $flashvars);

  # in the configuration there is also URL we're looking for
  if ($flashvars =~ /&file=(http[^&]+)&/) {
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
  $name =~ s/.*\/([^\/]+\.(flv|mp4)).*/$1/;
  debug("Filename: " . $name);
  return $url, title_to_filename($name);
}

1;
