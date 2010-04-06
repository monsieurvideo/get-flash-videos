# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Theonion; # horrible casing :(

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser) = @_;

  if ($browser->response->is_redirect) {
    $browser->get( $browser->response->header('Location') );

    if (!$browser->success) {
      die "Couldn't follow Onion redirect: " .
        $browser->response->status_line;
    }
  }

  my $title;
  if ($browser->content =~ /var video_title = "([^"]+)"/) {
    $title = $1;
  }
  else {
    $title = extract_info($browser)->{meta_title};
  }

  my $filename = title_to_filename($title);

  # They now pass the URL as a param, so the generic code can extract it.
  my $url = (FlashVideo::Generic->find_video($browser, $browser->uri))[0];

  return $url, $filename;
}

1;
