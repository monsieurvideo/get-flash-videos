# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Mofosex;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my $filename = title_to_filename($browser->content =~ /<title>(.*?)<\//);
  
  # I want to follow redirects now.
  $browser->allow_redirects;

  # Get the playlist and match for the url of the actual file
  my $playlist = ($browser->content =~ /videoPath=(.+?)%26page/)[0];
  $browser->get($playlist);
   
  my $url = ($browser->content =~ /<url>(.+?)<\/url>/)[0];
    
  return $url, $filename;
}

1;
