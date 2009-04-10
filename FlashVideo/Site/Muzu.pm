# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Muzu;

use strict;
use FlashVideo::Utils;
use HTML::Entities;

sub find_video {
  my ($self, $browser) = @_;

  my $filename;
  if ($browser->content =~ /id="trackHeading">(.*?)</) {
    $filename = title_to_filename(decode_entities($1));
  }
  $filename ||= get_video_filename();

  my $flashvars = ($browser->content =~ m'flashvars:"([^"]+)')[0];
  die "Unable to extract flashvars" unless $flashvars;

  my %map = (
    networkId    => "id",
    assetId      => "assetId",
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
