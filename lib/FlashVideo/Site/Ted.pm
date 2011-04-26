# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Ted;
use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser) = @_;

  my $url;
  if($browser->content =~ m{<param name="flashvars" value="vu=http://video.ted.com/[^"]*talk=([^&;]+);}) {
    my $embed_url = "http://www.ted.com/talks/$1.html";
    $browser->get($embed_url);
  }
  if($browser->content =~ m{<a href="(/talks[^"]+)">Watch high-res video}) {
    $url = URI->new_abs($1, $browser->uri);
    $browser->allow_redirects;
  } else {
    die "Unable to find download link";
  }

  # TODO - support subtitles. Available in JSON (urgh):
  #   http://www.ted.com/talks/subtitles/id/453/lang/eng
  # The ID can be pulled out of flashvars:
  #   ti:"453"

  my $title = extract_title($browser);
  $title =~ s/\s*\|.*//;
  my $filename = title_to_filename($title, "mp4");

  return $url, $filename;
}

1;
