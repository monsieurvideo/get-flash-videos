# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Grindtv;

use strict;
use FlashVideo::Utils;

my %sites = (
  Grindtv => "http://videos.grindtv.com/1/",
  Stupidvideos => "http://videos.stupidvideos.com/2/",
  Ringtv => "http://videos.ringtv.com/7/"
);

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my $site = ($self =~ /::([^:]+)$/)[0];
  my $base = $sites{$site};

  my $id;
  if($browser->content =~ /(?:baseID|video(?:ID)?)\s*=\s*['"]?(\d+)/) {
    $id = $1;
  }
  die "No ID found\n" unless $id;

  my $title = ($browser->content =~ /name="title" content="([^"]+)/i)[0];
  $title = extract_title($browser) unless $title;

  my $filename = title_to_filename($title);

  # I want to follow redirects now.
  $browser->allow_redirects;

  my $str = sprintf "%08d", $id;
  my $url = $base . join("/", map { substr $str, $_*2, 2 } 0 .. 3) . "/$id.flv";

  return $url, $filename;
}

1;
