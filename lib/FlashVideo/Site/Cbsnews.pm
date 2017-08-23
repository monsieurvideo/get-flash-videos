# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Cbsnews;

use strict;
use FlashVideo::Utils;
use base 'FlashVideo::Site::Cnet';

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my $video_id;
  if($browser->content =~ /CBSVideo\.setVideoId\(["']([0-9]+)["']\)/) {
    $video_id = $1;
  } else {
    die "Could not find video id. If this is a valid CBS News video, please file a bug report at https://github.com/monsieurvideo/get-flash-videos/issues";
  }
  return $self->get_video($browser, $video_id);
}

1;
