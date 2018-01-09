# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::DASHDownloader;

use strict;
use warnings;
use base 'FlashVideo::Downloader';
use FlashVideo::Utils;
use FlashVideo::JSON;
use Term::ProgressBar;

my $bitrate_index = {
  high   => 0,
  medium => 1,
  low    => 2
};

sub download {
  my ($self, $args, $file, $browser) = @_;

  info "Not implemented yet";
}
1;
