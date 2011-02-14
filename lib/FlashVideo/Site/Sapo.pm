# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Sapo;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser) = @_;

  my ($video_url, $type);
  
  if ($browser->content =~ m{flvplayer-sapo\.swf\?file=(http://[^&"]+)}) {
    $video_url = $1;

    if ($video_url =~ m{/mov}) {
      $type = "mp4";
    }
  }
  else {
    die "Couldn't extract Sapo video URL";
  }

  (my $title = extract_title($browser)) =~ s/ - SAPO V\x{ed}deos//;

  my $filename = title_to_filename($title, $type);

  $browser->allow_redirects(1);

  return $video_url, $filename;
}

1;
