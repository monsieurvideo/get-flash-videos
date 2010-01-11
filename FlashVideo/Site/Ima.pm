# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Ima;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser) = @_;

  my($id) = $browser->uri =~ /id=(\d+)/;
  die "ID not found" unless $id;

  my $rpc = "http://www.ima.umn.edu/videos/video_rpc.php?id=$id";
  $browser->get($rpc);

  my($title) = $browser->content =~ m{<video_title>(.*)</video_title>};
  my($instance) = $browser->content =~ m{<video_instance>(.*)</video_instance>};
  my($file) = $browser->content =~ m{<video_file>(.*)</video_file>};
#  $file =~ s/\.flv$//;

  return {
    rtmp => "rtmp://reel.ima.umn.edu/ima/$instance/$file",
    flv  => title_to_filename($title)
  };
}

sub can_handle {
  my($self, $browser) = @_;

  return $browser->uri->host =~ /ima\.umn\.edu/i;
}

1;
