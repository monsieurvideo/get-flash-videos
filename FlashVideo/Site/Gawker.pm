# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Gawker;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser) = @_;

  my $title = extract_title($browser);
  $title =~ s/^\w+\s+-\s*//;
  $title =~ s/\s*-\s+\w+$//;
  my $filename = title_to_filename($title);

  my $url = "http://cache." . $browser->uri->host . "/assets/video/" .
    ($browser->content =~ /newVideoPlayer\("([^"]+)/)[0];

  return $url, $filename;
}

sub can_handle {
  my($self, $browser, $url) = @_;

  return $browser->content =~ /newVideoPlayer/;
}

1;
