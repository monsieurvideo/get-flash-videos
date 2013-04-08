# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Facebook;

use strict;
use FlashVideo::Utils;

use URI::Escape;

our $VERSION = '0.01';
sub Version { $VERSION; }

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  # If we should process Facebook's Like button, leave
  return if ($embed_url =~ /http:\/\/www\.facebook\.com\/plugins\/like\.php/);

  # Grab the file from the page..
  my $params = ($browser->content =~ /\["params","(.+?)"\]/)[0];
  $params =~ s/\\u([[:xdigit:]]{1,4})/chr(eval("0x$1"))/egis;
  $params = uri_unescape($params);
  my $url = ($params =~ /"hd_src":"([^"]*)"/)[0];
  if (!$url) { $url = ($params =~ /"sd_src":"([^"]*)"/)[0]; }
  $url =~ s/\\\//\//g;
  die "Unable to extract url" unless $url;

  my $filename = ($url =~ /([^\/]*)\?/)[0];

  return $url, $filename;
}

1;
