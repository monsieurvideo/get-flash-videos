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

  debug ("Content: " . $browser->content);
  if ($browser->content =~ /file: "(http:[^"]*\.(flv|mp4))",/) {
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
