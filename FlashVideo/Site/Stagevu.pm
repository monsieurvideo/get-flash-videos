# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Stagevu;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser) = @_;

  my($title) = $browser->content =~ /<title>(.*?)<\/title>/;
  $title =~ s/\s*-\s*Stagevu.*?$//;

  # Generic can handle this so just pass it over to that
  my($url) = FlashVideo::Generic->find_video($browser);

  return $url, title_to_filename($title);
}

1;
