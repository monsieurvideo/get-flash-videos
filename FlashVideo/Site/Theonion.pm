# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Theonion; # horrible casing :(

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser) = @_;

  # Get the video ID
  my $video_id;

  if ($browser->content =~ /<meta name="nid" content="(\d+)"/) {
    $video_id = $1;
  }
  elsif ($browser->content =~ /var videoid = ["'](\d+)["'];/) {
    $video_id = $1;
  }
  
  die "Couldn't find Onion video ID" unless $video_id;

  # Get XML with FLV details
  # TODO - support "bookend" (online exclusive videos).
  $browser->get("http://www.theonion.com/content/xml/$video_id/video");

  die "Couldn't download Onion XML: " . $browser->response->status_line
    if !$browser->success;

  # Generic can handle this XML so just pass it over to that.
  my ($url, @filenames) = FlashVideo::Generic->find_video($browser);

  # We can probably make a better guess for the filename than generic can
  # though.
  my $has_xml_simple = eval { require XML::Simple };
  
  # Don't die if XML::Simple isn't installed, as strictly speaking it's not
  # needed for this video -- it just lets us have a better title.
  if ($has_xml_simple) {
    my $video_rss = eval {
      XML::Simple::XMLin($browser->content);
    };

    if (my $title_from_rss = $video_rss->{channel}->{item}->[0]->{title}) {
      $title_from_rss = title_to_filename($title_from_rss); 

      # Likely to be a better filename so put it first for people who are
      # using --yes
      unshift @filenames, $title_from_rss;
    }
  }

  return ($url, @filenames);
}

1;
