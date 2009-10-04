# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Videojug;

use strict;
use FlashVideo::Utils;
use LWP::Simple;

my $playlist_url = "http://www.videojug.com/views/film/playlist.aspx?items=&userName=&ar=16_9&id=";

sub find_video {
  my ($self, $browser) = @_;

  die "Must have XML::Simple installed to download from Videojug"
    unless eval { require XML::Simple };

  # Get the video ID
  my $video_id;
  
  if ($browser->content =~
    /<meta name=["']video-id["'] content="([A-F0-9a-f\-]+)"/) {
    $video_id = $1;
  } else {
    die "Couldn't find video ID in Videojug page";
  }

  $browser->get($playlist_url . $video_id);

=pod

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
    my $xml = XML::Simple::XMLin($browser->content);

    # Shape list seems to be sorted in order of quality, we'll go for the highest.
    my $shape = $xml->{Shapes}->{Shape}->[-1];
    # Find a location for this shape..
    my $location = (grep { $shape->{Locations} =~ /\Q$_->{Name}\E/ }
      @{$xml->{Locations}->{Location}})[0];

    $video_url = sprintf "%s%s__%sENG.flv",
      $location->{Url}, $xml->{Items}->{Media}->{Prefix}, $shape->{Code};

    $filename = title_to_filename($xml->{Items}->{Media}->{Title});
  };
  die "Unable to retrieve/parse Videojug playlist. $@" if $@;

  die "Couldn't find video URL" unless $video_url;

  return $video_url, $filename;
}

1;
