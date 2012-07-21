# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Pinkbike;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  # Extract filename from page title
  my $title = extract_title($browser);
  debug("Found title : " . $title);
  my $filename = title_to_filename($title);
  debug("Filename : " . $filename);

  my $video_id = ($embed_url =~ m/\/video\/(\d+)\/?$/)[0];

  die "Unable to extract url" unless $video_id;

  my $url = "http://lv1.pinkbike.org/vf/" . (int($video_id / 10000)) . "/pbvid-" . $video_id . ".flv";
  debug("Video URL: " . $url);

  return $url, $filename;
}

1;
