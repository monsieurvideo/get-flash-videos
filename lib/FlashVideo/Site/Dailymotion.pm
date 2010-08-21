# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Dailymotion;

use strict;
use FlashVideo::Utils;
use URI::Escape;

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;

  if ($browser->content =~ /content.is.not.available.for.your.country/i) {
    error "Can't (yet) download this video because it's not available " .
          "in your area";
    exit 1;
  }
 
  $browser->allow_redirects;

  $browser->content =~ /<h1[^>]*>(.*?)<\//;
  my $filename = title_to_filename($1);

  my $video;
  if ($browser->content =~ /"video", "([^"]+)/) {
    $video = uri_unescape($1);
  } else {
    if ($embed_url !~ m!/swf/!) {
      $browser->uri =~ m!video(?:%2F|/)([^_]+)!;
      $embed_url = "http://www.dailymotion.com/swf/$1";
    }

    $browser->get($embed_url);

    die "Must have Compress::Zlib for embedded Dailymotion videos\n"
      unless eval { require Compress::Zlib; };

    my $data = Compress::Zlib::uncompress(substr $browser->content, 8);

    $data =~ /\{\{video\}\}\{\{(.*?)\}\}/;
    $video = $1;

    if($data =~ /videotitle=([^&]+)/) {
      $filename = title_to_filename(uri_unescape($1));
    }
  }

  if(!$video) {
    # Sometimes dailymotion actually embeds another site, so check that..
    my($package, $possible_url) = FlashVideo::URLFinder::find_package($browser->uri, $browser);

    if($package ne __PACKAGE__) {
      return $package->find_video($browser, $possible_url, $prefs);
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

  return $url, $filename;
}

1;
