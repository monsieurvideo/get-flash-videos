# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Videojug;

use strict;
use FlashVideo::Utils;
use LWP::Simple;

sub find_video {
  my ($self, $browser) = @_;

  # Get the video ID
  my $video_id;
  
  if ($browser->content =~
    /<meta name=["']video-id["'] content="([A-F0-9a-f\-]+)"/) {
    $video_id = $1;
  }
  else {
    die "Couldn't find video ID in Videojug page";
  }

  # Get the base of the FLV filename, for example:
  #   how-to-make-sushi-rice
  # There are two methods of getting this -- looking for an image URL in
  # the page, or looking at the URL itself. On some videos like 
  #   http://www.videojug.com/film/how-to-make-homemade-bagels
  # the URL doesn't match up with name itself, so it seems like the image
  # URL is a more accurate test.
  my $base_flv_filename;

  # Appears in the page as an image link, for example:
  # href="http://content5.videojug.com/b9/b9ae53fa-18b2-beee-828f-ff0008c918d8/how-to-make-new-york-style-bagels.PostIt.jpg"
  if ($browser->content =~
    m'<link rel="image_src"\s+href=".*?videojug\.com/([a-fA-F0-9]{2}/[a-fA-F0-9\-]{10,}/.*?)(?:PostIt)?(?:\.jpg)') {
    $base_flv_filename = $1;
    $base_flv_filename =~ s/\.$//;
    $base_flv_filename = (split /\//, $base_flv_filename)[-1];
  }

  if (!$base_flv_filename) {
    if ($browser->uri()->as_string =~ m'/([^/]+)$') {
      $base_flv_filename = $1;
    }
    else {
      die "Couldn't extract base FLV filename for Videojug";
    }
  }

  # Can't properly figure out which host videos are on, so try several. 
  my @possible_hosts = ("content.videojug.com");
  push @possible_hosts, map { "content$_.videojug.com" } (2 .. 5);

  # Do this before getting the video URL because url_exists() will alter
  # $browser.
  my $filename = title_to_filename(extract_title($browser));

  my $video_url;

  foreach my $possible_host (@possible_hosts) {
    # The path is in the following format:
    # /97/979c8432-d8b4-8a4a-e652-ff0008c93e69/how-to-air-kiss__FW8ENG.flv
    # where the first directory is the first two characters of the video
    # ID. The videos I've tested have __FW8ENG.flv at the end, but I can't
    # figure out where this is being added.

    my $url = sprintf "http://%s/%s/%s/%s__FW8ENG.flv",
              $possible_host, substr($video_id, 0, 2), $video_id,
              $base_flv_filename;

    if (url_exists($browser, $url)) {
      $video_url = $url;
      last;
    }
  }

  die "Couldn't get video URL" unless $video_url;

  return $video_url, $filename;
}

1;
