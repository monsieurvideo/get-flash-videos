# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Videojug;

use strict;
use FlashVideo::Utils;

my $playlist_url = "http://www.videojug.com/views/film/playlist.aspx?items=&userName=&ar=16_9&id=";

sub find_video {
  my ($self, $browser) = @_;

  # If this is an interview rather than a normal video, have to use a
  # different playlist URL. Interviews are actually separate videos, one
  # for each question.
  my $interview_clip;

  if ($browser->uri->as_string =~ m'/interview/'i) {
    $playlist_url =
      "http://www.videojug.com/views/interview/playlist.aspx?ar=16_9&id=";

    # Use the browser fragment (like #interview-question-here) to find out
    # which interview clip to download.
    $interview_clip = $browser->uri->fragment; 
  }

  # Get the video ID
  my $video_id;
  
  if ($browser->content =~
    /<meta name=["']video-id["'] content="([A-F0-9a-f\-]+)"/) {
    $video_id = $1;
  } else {
    die "Couldn't find video ID in Videojug page";
  }

  $browser->get($playlist_url . $video_id);

=for comment

  This XML gives us:

  ...
  <Locations>
    <Location Name="content.videojug.com" Url="http://content.videojug.com/db/db67075d-e3f5-39af-9481-ff0008c9de32/" />
    ...
  </Locations>
  <Items>
    <Media Type="Video" Prefix="new-film-4" Title="How To Replace The Batteries In Your Laptop" Keywords="technology and cars,computers,made by you,installing computer parts,made by you competition" />
  </Items>
  ...
  <Shapes>
    <Shape Code="FS7" Locations="content.videojug.com, direct" />
    ...
  </Shapes>

  'Shape' appears to refer to the quality of the video.

=cut

  my($video_url, $filename);
  eval {
    my $xml = from_xml($browser);

    # Shape list seems to be sorted in order of quality, we'll go for the highest.
    my $shape = $xml->{Shapes}->{Shape}->[-1];
    # Find a location for this shape..
    my $location = (grep { $shape->{Locations} =~ /\Q$_->{Name}\E/ }
      @{$xml->{Locations}->{Location}})[0];

    # Getting prefix and title is different based on whether it's an
    # interview or not, as there are multiple media items defined for
    # interviews.
    my ($prefix, $title);

    if ($interview_clip) {
      ($prefix, $title) = get_prefix_and_title($xml, $interview_clip); 
    }
    else {
      $prefix = $xml->{Items}->{Media}->{Prefix};
      $title = $xml->{Items}->{Media}->{Title};
    }

    $video_url = sprintf "%s%s__%sENG.flv",
      $location->{Url}, $prefix, $shape->{Code};

    $filename = title_to_filename($title);
  };
  die "Unable to retrieve/parse Videojug playlist. $@" if $@;

  die "Couldn't find video URL" unless $video_url;

  return $video_url, $filename;
}

sub get_prefix_and_title {
  my ($xml, $video_name) = @_;

  foreach my $media (@{ $xml->{Items}->{Media} }) {
    # This is frail, but try to go from the formatted video title to the
    # title in the same format as in the fragment.
    my $title = lc $media->{Title};
    $title =~ s/ /-/g;
    $title =~ s/[^a-z0-9\-]//g;

    if ($title eq $video_name) {
      return $media->{Prefix}, $media->{Title};
    }
  }

  die "Couldn't find prefix for video '$video_name'";
}

1;
