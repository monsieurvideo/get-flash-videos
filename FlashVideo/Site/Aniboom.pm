# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Aniboom;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my ($id, $url, $title);

  if ($browser->uri->as_string =~ /\/animation-video\/(\d*)\/([^\/]*)/) {
    $id = $1;
    $title = $2;
    $title =~ s/-/ /g;
  } else {
    die "Could not detect video ID!";
  }
  
  $browser->get("http://www.aniboom.com/animations/player/handlers/animationDetails.aspx?mode=&movieid=$id");

  if ($browser->content =~ /(?:mp4|flv)=([^&]*)/) {
    $url = $1;
    $url =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
  } else {
    die "Could not get flv/mp4 location!";
  }
  
  return $url, title_to_filename($title);
}

1;

