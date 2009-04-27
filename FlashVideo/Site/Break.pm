# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Break;

use strict;
use FlashVideo::Utils;
use URI::Escape;

sub find_video {
  my($self, $browser) = @_;

  if($browser->uri->host eq "embed.break.com") {
    # Embedded video
    if(!$browser->success && $browser->response->header('Location') !~ /sVidLoc/) {
      $browser->get($browser->response->header('Location'));
    }

    if($browser->response->header("Location") =~ /sVidLoc=([^&]+)/) {
      my $url = uri_unescape($1);
      my $filename = title_to_filename((split /\//, $url)[-1]);

      return $url, $filename;
    }
  }

  my $path = ($browser->content =~ /sGlobalContentFilePath='([^']+)'/)[0];
  my $filename = ($browser->content =~ /sGlobalFileName='([^']+)'/)[0];

  die "Unable to extract path and filename" unless $path and $filename;

  my $video_path = ($browser->content =~ /videoPath\s*(?:',|=)\s*['"]([^'"]+)/)[0];

  # I want to follow redirects now.
  $browser->allow_redirects;

  return $video_path . $path . "/" . $filename . ".flv",
    title_to_filename($filename);
}

1;
