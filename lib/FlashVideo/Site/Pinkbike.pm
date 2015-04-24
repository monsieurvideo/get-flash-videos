# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Pinkbike;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;
  my ($url, $filename, $quality);

  # Extract filename from page title
  my $title = extract_title($browser);
  debug("Found title : " . $title);

  $quality = {high => '1080p', medium => '720p', low => '480p'}->{$prefs->{quality}};

  if (my $video_id = ($embed_url =~ m/\/video\/(\d+)\/?$/)[0]) {
      $url = "http://lv1.pinkbike.org/vf/" . (int($video_id / 10000)) . "/pbvid-" . $video_id . ".flv";
      $filename = title_to_filename($title);
  } elsif (my $source = ($browser->content =~ m/<source data-quality=\\"$quality\\" src=\\"(https?:\/\/.+?\.mp4)\\"/)) {
      $url = $1;
      $filename = title_to_filename($title, 'mp4');
  }

  die "Unable to extract url" unless $url;
  debug("Video URL: " . $url);
  debug("Filename : " . $filename);

  return $url, $filename;
}

1;
