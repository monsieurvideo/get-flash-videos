# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Muzu;

use strict;
use FlashVideo::Utils;
use HTML::Entities;

sub find_video {
  my ($self, $browser) = @_;

  # Sometimes redirects to country-specific sites, sigh...
  if ($browser->response->code == 302) {
    $browser->get($browser->response->header('Location'))
  }

  $browser->content =~ /id="trackHeading">(.*?)</;
  my $title = $1;

  if (!$title) {
    $browser->content =~ /id="videosPageMainTitleH1">(.*?)</s;
    $title = $1;
  }
  
  my $filename = title_to_filename(decode_entities($title));

  my $flashvars = ($browser->content =~ m'flashvars:(?:\s+getPlayerData\(\)\s+\+\s+)?"([^"]+)')[0];
  die "Unable to extract flashvars" unless $flashvars;

  my %map = (
    networkId    => "id",
    assetId      => "assetId",
    vidId        => "assetId",
    startChannel => "playlistId",
  );

  my $playAsset = "http://www.muzu.tv/player/playAsset/?";
  for(split /&/, $flashvars) {
    my($n, $v) = split /=/;
    $playAsset .= "$map{$n}=$v&" if exists $map{$n};
  }

  $browser->get($playAsset);
  die "Unable to get $playAsset" if $browser->response->is_error;

  my $url = ($browser->content =~ /src="([^"]+)/)[0];
  $url = decode_entities($url);
  die "Unable to find video URL" unless $url;

  return $url, $filename;
}

1;
