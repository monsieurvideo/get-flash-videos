# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Freevideo; # .ru

use strict;
use Encode;
use FlashVideo::Utils;
use URI::Escape;

sub find_video {
  my ($self, $browser) = @_;

  my $ticket;
  if ($browser->uri->as_string =~ /\?id=(.*?)$/) {
    $ticket = $1;
  }

  $browser->post(
    "http://freevideo.ru/video/view/url/-/" . int(rand 100_000), 
    [
      onLoad       => '[type Function]',
      highquality  => 0,
      getvideoinfo => 1,
      devid        => 'LoadupFlashPlayer',
      after_adv    => 0,
      before_adv   => 1,
      frame_url    => 1,
      'ref'        => $browser->uri->as_string,
      video_url    => 1,
      ticket       => $ticket,
    ]
  );

  if (!$browser->success) {
    die "Posting to Freevideo failed: " . $browser->response->status_line();
  }

  my $video_data = uri_unescape($browser->content);

  my $url;

  if ($video_data =~ m'vidURL=(http://.*?\.flv)') {
    $url = $1;
  }
  else {
    die "Couldn't find Freevideo URL";
  }

  my $title;

  if ($video_data =~ /title=(.*?)&userNick/) {
    $title = $1;
  }

  # All your double encoding is belong to us!
  $title = decode('utf-8', $title);

  return $url, title_to_filename($title);
}

1;
