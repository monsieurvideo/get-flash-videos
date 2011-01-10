# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Scivee; # horrible casing :(

# for use with Scivee.tv
# 

use strict;
use FlashVideo::Utils;
use HTML::Entities;
sub find_video {

#  print title_to_filename(decode_entities("The+Algorithmic+Lens%3A+How+the+Computational+Perspective+is+Transforming+the+Sciences.mp3"));
#  also /asset/audio/$vid
  my ($self, $browser) = @_;
  
  my $title;
  if ($browser->content =~ /title\>([^\|]+)/) {
    $title = $1;
  }
  else {
#$title = extract_info($browser)->{meta_title};
    $title = extract_info($browser)->{title};
  }
  my $filename = title_to_filename($title);
# since I can't figure how to get the request url
  my $vid;
  if ($browser->content =~ /\/ratings\/(\d+)/) {
    $vid = $1;
  }
  elsif ($browser->content =~ /flashvars="id=(\d+)/) {
    $vid = $1;
  }
  else {
#   print $browser->content;
    die "Could not find video!";
  }
  my $url = "http://www.scivee.tv/asset/video/$vid";

  return $url, $filename;
}

1;
