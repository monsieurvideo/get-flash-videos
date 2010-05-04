# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Cartoonnetwork;

use strict;
use FlashVideo::Utils;

use Date::Format;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my $has_xml_simple = eval { require XML::Simple };
  if(!$has_xml_simple) {
    die "Must have XML::Simple installed to download Cartoonnetwork videos";
  }

  my $video_id;

  if ($browser->uri->as_string =~ /episodeID=([a-z0-9]*)/) {
    $video_id = $1;
  }

  my $xml;

  $browser->get("http://www.cartoonnetwork.com/cnvideosvc2/svc/episodeSearch/getEpisodesByIDs?ids=$video_id");
  $xml = XML::Simple::XMLin($browser->content);
  my $episodes = $xml->{episode};
  my $episode = ref $episodes eq 'ARRAY' ?
    (grep { $_->{id} eq $video_id } @$episodes)[0] :
    $episodes;

  my $filename;

  $filename = $episode->{title} . '.flv';

  my $date;

  # as seen in http://www.cartoonnetwork.com/video/tools/js/videoConfig_videoPage.js
  my $m;
  my $M;
  my $null;
  ($null, $m) = localtime();
  if ($m >= 0 && $m <= 15){
    $M = "0";
  } elsif ($m >= 16 and $m <= 30) {
    $M = "15";
  } elsif ($m >= 31 and $m <= 45) {
    $M = "30";
  } elsif ($m >= 46 and $m <= 59) {
    $M = "45";
  }

  $date = time2str("%m%d%Y%H$M", time);

  my $content_id;
  my $url;

  use Data::Dumper;

  foreach my $key (keys (%{$episode->{segments}->{segment}})){
#  foreach ($episode->{segments}->{segment}){
    $content_id = $key;
    $browser->post("http://www.cartoonnetwork.com/cnvideosvc2/svc/episodeservices/getVideoPlaylist",
      Content  => "id=$content_id&r=$date"
    );

    # the output has some errors in it, let's just use regular expressions
    #$xml = XML::Simple::XMLin($browser->content);
    #$url = $xml->{entry}->{ref}->{href};

    if ($browser->content =~ /<ref href="([^"]*)" \/>/){
      $url = $1;
    }
  }

  return $url, $filename;
}

1;
