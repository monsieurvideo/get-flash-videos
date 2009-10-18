# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Nicovideo;

use strict;
use FlashVideo::Utils;
use URI::Escape;

sub find_video {
  my ($self, $browser, $embed_url) = @_;
  my $id = ($embed_url =~ /([ns]m\d+)/)[0];
  die "No ID found\n" unless $id;

  my $base = "http://ext.nicovideo.jp/thumb_watch/$id";

  if($embed_url !~ /ext\.nicovideo\.jp\/thumb_watch/) {
    $embed_url = "$base?w=472&h=374&n=1";
  }

  $browser->get($embed_url);
  my $playkey = ($browser->content =~ /thumbPlayKey: '([^']+)/)[0];
  die "No playkey found\n" unless $playkey;

  my $title = ($browser->content =~ /title: '([^']+)'/)[0];
  $title =~ s/\\u([a-f0-9]{1,5})/chr hex $1/eg;

  $browser->get($base . "/$playkey");
  my $url = uri_unescape(($browser->content =~ /url=([^&]+)/)[0]);

  return $url, title_to_filename($title, $id =~ /^nm/ ? "swf" : "flv");
}

1;
