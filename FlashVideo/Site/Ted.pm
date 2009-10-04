# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Ted;
use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser) = @_;

  my $url;
  if($browser->content =~ m{<a href="(/talks[^"]+)">Watch this talk as high-res}) {
    $url = URI->new_abs($1, $browser->uri);
    $browser->allow_redirects;
  } else {
    die "Unable to find download link";
  }

  my $title = extract_title($browser);
  $title =~ s/\s*\|.*//;
  my $filename = title_to_filename($title, "mp4");

  return $url, $filename;
}

1;
