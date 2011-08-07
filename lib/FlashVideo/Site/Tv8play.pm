# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Tv8play;
use strict;
use FlashVideo::Utils;
use base 'FlashVideo::Site::Tv3play';


sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;
  return $self->find_video_viasat($browser,$embed_url,$prefs);
}
1;
