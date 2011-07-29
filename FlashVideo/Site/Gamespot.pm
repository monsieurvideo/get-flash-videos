# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Gamespot;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my $has_xml_simple = eval { require XML::Simple };
  if(!$has_xml_simple) {
    die "Must have XML::Simple installed to download Gamespot videos";
  }

  my $id;
  if($browser->content =~ /id=(\w+)/) {
    $id = $1;
  } elsif($embed_url =~ m!xml.php%3Fid%3D([^%]*)!) {
    $id = $1;
  }
  die "No ID found\n" unless $id;

  $browser->get("http://www.gamespot.com/pages/video_player/xml.php?id=" . $id . "&mode=user_video");

  my $xml = eval {
    XML::Simple::XMLin($browser->content)
  };

  if ($@) {
    die "Couldn't parse Gamespot XML: $@";
  }

  my $title = $xml->{playList}->{clip}->{title};
	print "$title\n";
  my $filename = title_to_filename($title);

  my $url = $xml->{playList}->{clip}->{URI};
  $browser->allow_redirects;

  return $url, $filename;
}

1;

