# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Oppetarkiv;

use strict;
use warnings;

use FlashVideo::Utils;
use FlashVideo::JSON;
use HTML::Entities;
use base 'FlashVideo::Site::Svtplay';

our $VERSION = '0.01';
sub Version() { $VERSION;}

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;
  $self->find_video_svt($browser, $embed_url, $prefs, 1);
}

1;
