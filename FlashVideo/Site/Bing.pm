# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Bing;
use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;

  # Extract the video url from the page.
  # Attempt to get the higher quality .wmv first, falling back to the .flv
  my $url;
  if ($browser->content =~ /url:\s*'([^']+\.wmv)'/) {
    $url = $1;
  } elsif ($browser->content =~ /url:\s*'([^']+\.flv)'/) {
    $url = $1;
  } else {
    die "Unable to extract video url" unless $url;
  }

  # Quick and dirty unencode of the url
  $url =~ s/\\x3a/:/g;
  $url =~ s/\\x2f/\//g;

  # Extract the video title from the page
  my $filename;
  my $fileExt = ($url =~ /(\.[a-z]+)$/i)[0];
  if ($browser->content =~ /sourceFriendly:\s*'([^']+)'[\s\S]+?\s*title:\s*'([^']+)'/) {
    $filename = title_to_filename("$1 - $2.$fileExt");
  }
  $filename ||= get_video_filename();

  return $url, $filename;
}

1;
