# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Cartoonnetwork;

use strict;
use FlashVideo::Utils;
use POSIX();

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my $video_id;
  if ($browser->uri->as_string =~ /episodeID=([a-z0-9]*)/) {
    $video_id = $1;
  }

  $browser->get("http://www.cartoonnetwork.com/cnvideosvc2/svc/episodeSearch/getEpisodesByIDs?ids=$video_id");
  my $xml = from_xml($browser);
  my $episodes = $xml->{episode};
  my $episode = ref $episodes eq 'ARRAY' ?
    (grep { $_->{id} eq $video_id } @$episodes)[0] :
    $episodes;

  my $title = $episode->{title};

  # as seen in http://www.cartoonnetwork.com/video/tools/js/videoConfig_videoPage.js
  my @gmtime = gmtime;
  $gmtime[1] = 15 * int($gmtime[1] / 15);
  my $date = POSIX::strftime("%m%d%Y%H%M", @gmtime);

  my $url;
  foreach my $key (keys (%{$episode->{segments}->{segment}})){
    my $content_id = $key;
    $browser->post("http://www.cartoonnetwork.com/cnvideosvc2/svc/episodeservices/getVideoPlaylist",
      Content  => "id=$content_id&r=$date"
    );

    if ($browser->content =~ /<ref href="([^"]*)" \/>/){
      $url = $1;
    }
  }

  return $url, title_to_filename($title);
}

1;
