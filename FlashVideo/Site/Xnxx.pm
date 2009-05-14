# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Xnxx;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  # Grab the file from the page..
  my $url = ($browser->content =~ /flv_url=(.+?)&/)[0];
  die "Unable to extract url" unless $url;

  # Extract filename from page and format
  $browser->content =~ /(?:<span class="style5">|<td style="font-size: 20px;">\s*)<strong>([^<]+)/;
  my $filename = title_to_filename($1, $url);
    
  return $url, $filename;
}

1;
