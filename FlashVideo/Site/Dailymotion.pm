# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Dailymotion;

use strict;
use FlashVideo::Utils;
use URI::Escape;

sub find_video {
  my ($self, $browser, $url) = @_;

  my $filename;
  if ($browser->content =~ /<h1[^>]*>(.*?)<\//) {
    $filename = title_to_filename($1);
  }
  $filename ||= get_video_filename();

  my $video;
  if ($browser->content =~ /"video", "([^"]+)/) {
    $video = uri_unescape($1);
  } elsif ($url =~ m!/swf/!) {
    $browser->get($url);

    die "Must have Compress::Zlib for embedded Dailymotion videos\n"
      unless eval { require Compress::Zlib; };

    my $data = Compress::Zlib::uncompress(substr $browser->content, 8);

    $data =~ /\{\{video\}\}\{\{(.*?)\}\}/;
    $video = $1;

    if($data =~ /videotitle=([^&]+)/) {
      $filename = title_to_filename(uri_unescape($1));
    }
  }

  die "Couldn't find video parameter." unless $video;

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
