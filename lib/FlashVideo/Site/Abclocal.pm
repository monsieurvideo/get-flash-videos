# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Abclocal;

use strict;
use FlashVideo::Utils;
use Data::Dumper;
use File::Basename;

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;

  my($station,$id) = $browser->content =~ m{http://cdn.abclocal.go.com/[^"']*station=([^&;"']+)[^"']*mediaId=([^&;"']+)}s;

  die "No media id and station found" unless $id;

  $browser->get("http://cdn.abclocal.go.com/$station/playlistSyndicated?id=$id");

  my @tmp = $browser->content =~ m{<video *videopath="([^"]*)"[^>]*width="([^"]*)"[^>]*height="([^"]*)"[^>]*>}s ;
  my(@videos);
  for (my $i = 0; $i < @tmp; $i+=3)
  {
    push @videos, { "playpath" => $tmp[$i], "resolution" => [$tmp[$i+1], $tmp[$i+2]] };
  }

  my $video = $prefs->quality->choose(@videos);

  my $url = $video->{"playpath"};

  return $url, File::Basename::basename($url);
}

1;
