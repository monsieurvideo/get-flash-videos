# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Blip;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;
  my $base = "http://blip.tv";

  my $id;
  if($embed_url =~ m{flash/(\d+)}) {
    $id = $1;
  } else {
    $browser->get($embed_url);

    if($browser->response->is_redirect
        && $browser->response->header("Location") =~ m!(?:/|%2f)(\d+)!i) {
      $id = $1;
    } else {
      $id = ($browser->content =~ m!/rss/flash/(\d+)!)[0];
    }
  }

  # Sometimes the ID is supplied in an odd way.
  if (!$id) {
    # Video ID is somehow related to the ID of a comment posted on the
    # site, slightly odd.
    if ($browser->content =~ /post_masthed_(\d+)/) {
      $id = $1;
    }
  }

  die "No ID found\n" unless $id;

  $browser->get("$base/rss/flash/$id");

  my $xml = from_xml($browser);

  my $content = $xml->{channel}->{item}->{"media:group"}->{"media:content"};

  my $url = ref $content eq 'ARRAY' ? $content->[0]->{url} : $content->{url};

  my $filename = title_to_filename($xml->{channel}->{item}->{title}, $url);

  # I want to follow redirects now.
  $browser->allow_redirects;

  return $url, $filename;
}

1;
