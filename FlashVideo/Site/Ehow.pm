# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Ehow;

use strict;
use FlashVideo::Utils;
use URI::Escape;

sub find_video {
  my ($self, $browser) = @_;

  # Get the video ID
  my $video_id;
  if ($browser->content =~ /flashvars=(?:&quot;|'|")id=(\w+)&/) {
    $video_id = $1;
  }
  else {
    die "Couldn't extract video ID from page";
  }

  # Get the embedding page
  my $embed_url =
    "http://www.ehow.com/embedvars.aspx?isEhow=true&show_related=true&" .
    "from_url=" . uri_escape($browser->uri->as_string) .
    "&id=" . $video_id;

  my $title;
  if ($browser->content =~ /<div\ class="DetailHeader">
                            <h1\ class="SubHeader">(.*?)<\/h1>/x) {
    $title = $1;
  }

  $browser->get($embed_url);

  if ($browser->content =~ /&source=(http.*?flv)&/) {
    return uri_unescape($1), title_to_filename($title);
  }
  else {
    die "Couldn't extract Flash video URL from embed page";
  }
}


1;
