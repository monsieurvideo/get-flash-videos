# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Megavideo;

use strict;
use FlashVideo::Utils;
use URI::Escape;

my %sites = (
  Megavideo => "megavideo.com",
  Megaporn  => "megaporn.com/video",
);

sub find_video {
  my ($self, $browser) = @_;

  my $site = $sites{($self =~ /::([^:]+)$/)[0]};

  # Get the video ID
  my $v;
  if ($browser->content =~ /\.v\s*=\s*['"]([^"']+)/
      || $browser->uri =~ /v=([^&]+)/
      || $browser->response->header("Location") =~ /v=([^&]+)/) {
    $v = $1;
  } else {
    die "Couldn't extract video ID from page";
  }

  my $xml = "http://www.$site/xml/videolink.php?v=$v";
  $browser->get($xml);

  die "Unable to get video infomation" unless $browser->response->is_success;

  my $k1 = ($browser->content =~ /k1="(\d+)/)[0];
  my $k2 = ($browser->content =~ /k2="(\d+)/)[0];
  my $un = ($browser->content =~ /un="([^"]+)/)[0];
  my $s  = ($browser->content =~ /\ss="(\d+)/)[0];

  my $title = uri_unescape(($browser->content =~ /title="([^"]+)/)[0]);
  my $filename = title_to_filename($title) || get_video_filename();

  my $url = "http://www$s.$site/files/" . _decrypt($un, $k1, $k2) . "/";

  return $url, $filename;
}

sub _decrypt {
  my($un, $k1, $k2) = @_;

  my @c = split //, join "",
    map { substr unpack("B8", pack "h", $_), 4 } split //, $un;

  my @iv;
  my $i = 0;
  while($i < 384) {
    $k1 = ($k1 * 11 + 77213) % 81371;
    $k2 = ($k2 * 17 + 92717) % 192811;
    $iv[$i] = ($k1 + $k2) % 128;
    $i++;
  }

  $i = 256;
  while($i >= 0) {
    my $a = $iv[$i];
    my $b = $i-- % 128;

    ($c[$a], $c[$b]) = ($c[$b], $c[$a]);
  }

  $i = 0;
  while($i < 128) {
    $c[$i] ^= $iv[$i + 256] & 1;
    $i++;
  }

  $i = 0;
  my $c = "";
  while($i < @c) {
    $c .= unpack "h", pack "B8", "0000" . join "", @c[$i .. ($i + 4)];
    $i += 4;
  }

  return $c;
}

1;
