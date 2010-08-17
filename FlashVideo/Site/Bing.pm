# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Bing;
use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;

  my $title;
  if ($browser->content =~ /sourceFriendly:\s*'([^']+)'[\s\S]+?\s*title:\s*'([^']+)'/) {
    $title = "$1 - $2";
  }

  my $url;
  if ($browser->content =~ /formatCode:\s*1003,\s*url:\s*'([^']+)'/) {
    $url = $1;

    # Unencode the url
    $url =~ s/\\x([0-9a-f]{2})/chr hex $1/egi;
  }
  die "Unable to extract video url" unless $url;

  # MSNBC hosted videos use 302 redirects
  $browser->allow_redirects;

  return $url, title_to_filename($title);
}

1;
