# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Videobb;

use strict;
use FlashVideo::Utils;
use FlashVideo::JSON;
use MIME::Base64;

sub find_video {
  my ($self, $browser) = @_;

  if($browser->status == 302) {
    # in case we get a redirect
    $browser->allow_redirects;
    $browser->get;
  }
  my $flash_settings_b64 = ($browser->content =~ /<param value="setting=([^"]+)" name="FlashVars">/s)[0];
  my $flash_settings = decode_base64($flash_settings_b64);

  $browser->get($flash_settings);

  if (!$browser->success) {
    die "Couldn't download video settings: " . $browser->response->status_line;
  }

  my $settings_data = from_json($browser->content);

  # assuming that the last in the list is the highest res
  my $url = decode_base64($settings_data->{settings}{res}->[-1]->{u});
  
  my $title  = $settings_data->{settings}{video_details}{video}{title};
  my $filename = title_to_filename($title);

  return $url, $filename;
}

1;
