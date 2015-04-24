# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Liveleak;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my $url;
  if ($browser->content =~ /file: "((?!rtmp))([^"]+)"/) {
	  $url = $2;
  } else {
	  die "Unable to extract video url";
  }

  (my $title = extract_title($browser)) =~ s/LiveLeak\.com - //;

  return $url, title_to_filename($title, "mp4");
}

1;
