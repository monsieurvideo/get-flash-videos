# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Motherless;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my $url;
  print $embed_url
  if ($browser->content =~ /"file'[[:blank:]]*: "([^"]+)",/) {
    $url = $1."?start=0";
  } else {
    die "Unable to extract video url";
  }

  (my $title) = extract_title($browser) =~ /:\s+(.*)/;

  return $url, title_to_filename($title, "flv");
}

1;
