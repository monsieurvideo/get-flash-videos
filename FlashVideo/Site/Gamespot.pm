# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Gamespot;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  if(!eval { require XML::Simple }) {
    die "Must have XML::Simple installed to download Gamespot videos";
  }

  my($params) = $browser->content =~ /xml.php\?(id=[0-9]+.*?)&quot/;
  ($params) = $embed_url =~ /xml.php%3F(id%3D[^"&]+)/ unless $params;
  die "No params found\n" unless $params;

  $browser->get("http://www.gamespot.com/pages/video_player/xml.php?" . $params);

  my $xml = eval { XML::Simple::XMLin($browser->content) };
  die "Couldn't parse Gamespot XML: $@" if $@;

  my $title = $xml->{playList}->{clip}->{title};
  my $url = $xml->{playList}->{clip}->{URI};

  $browser->allow_redirects;
  return $url, title_to_filename($title);
}

1;

