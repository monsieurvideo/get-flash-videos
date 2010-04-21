# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Myvideo;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my $video_url;

  if ($browser->content =~ m{<link rel='image_src' href='(http://[^'"]+)'}) {
    $video_url = $1;
  }

  $video_url =~ s|thumbs/||;
  $video_url =~ s|_\d\.jpg$|.flv|;

  my $title = (split /\//, $browser->uri->as_string)[-1];

  return $video_url, title_to_filename($title);
}

1;
