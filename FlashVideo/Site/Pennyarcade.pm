# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Pennyarcade;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;
  my $tempUrl = $browser->content =~ /"http:\/\/api.indieclicktv.com\/player\/show\/([a-f0-9\/]*)\/default\/mplayer.js/;
  die "No Video Urls Found" unless $tempUrl;
  my $url = "http://ictv-pa-ec.indieclicktv.com/media/videos/$1/video.mp4";
  $browser->content =~ /<div class="title"><h1>([^<]*)<\/h1>/;
  my $title = $1;

  my $filename = "$title.mp4";

  return $url, $filename;
}

1;
