# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Dailymotion;

use strict;
use FlashVideo::Utils;
use URI::Escape;

sub find_video {
  my ($self, $browser) = @_;

  my $filename;
  if ($browser->content =~ /video_title"[^>]+>(.*?)<\//) {
    $filename = title_to_filename($1);
  }
  $filename ||= get_video_filename();

  my $video;
  if ($browser->content =~ /"video", "([^"]+)/) {
    $video = uri_unescape($1);
  } else {
    die "Couldn't find video parameter.";
  }

  my @streams;
  for(split /\|\|/, $video) {
    my($path, $type) = split /@@/;

    my($width, $height) = $path =~ /(\d+)x(\d+)/;

    push @streams, {
      width  => $width,
      height => $height,
      url    => URI->new_abs($path, $browser->uri)->as_string
    };
  }

  my $url = (sort { $b->{width} <=> $a->{width} } @streams)[0]->{url};
  $browser->allow_redirects;

  return $url, $filename;
}

1;
