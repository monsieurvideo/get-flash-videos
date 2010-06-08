# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Pennyarcade;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my($id) = $browser->content =~ m{"http://api.indieclicktv.com/player/show/([a-f0-9/]*)/default/mplayer.js};
  die "No Video Urls Found" unless $id;

  my $url = "http://ictv-pa-ec.indieclicktv.com/media/videos/$id/video.mp4";
  my($title) = $browser->content =~ /<div class="title"><h1>([^<]*)<\/h1>/;

  return $url, title_to_filename($title, "mp4");
}

1;
