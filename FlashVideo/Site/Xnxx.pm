# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Xnxx;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;
  my $filename;

  # Grab the file from the page..
  my $file = ($browser->content =~ /flv_url=(.+?)&/)[0];
  die "Unable to extract file" unless $file;

  # Get Video suffix from URL
  my $suffix = ($file =~ /http.+\.(.+)$/)[0];

  # Extract filename from page and format
  if ($browser->content =~ /(?:<span class="style5">|<td style="font-size: 20px;">\s*)<strong>([^<]+)/) {
    $filename = title_to_filename($1, $suffix);
  }
  $filename ||= get_video_filename($suffix);
    
  return $file, $filename;
}

1;
