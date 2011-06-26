# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Cnet;

use strict;
use FlashVideo::Utils;

my $cnet_api_base = "http://api.cnet.com";
my $cnet_api_rest = $cnet_api_base . "/restApi/v1.0";
my $cnet_api_video_search = $cnet_api_rest . "/videoSearch";

# /restApi/v1.0/videoSearch?videoIds=50106980&showBroadcast=true&iod=images,videoMedia,relatedLink,breadcrumb,relatedAssets,broadcast%2Clowcache&videoMediaType=preferred&players=Download,RTMP

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my $video_id;

  if($browser->content =~ /<param name="FlashVars" value="playerType=embedded&type=id&value=([0-9]+)" \/>/) {
    $video_id = $1;
  } elsif($browser->content =~ /assetId: '([0-9]+)',/) {
    $video_id = $1;
  } else {
    die "Could not find video ID; you may have to click the 'share' link on the flash player to get the permalink to the video.";
  }

  return get_video($browser, $video_id);
}

sub get_video {
  my ($browser, $video_id) = @_;

  $browser->get($cnet_api_video_search . "?videoIds=" . $video_id . "&iod=videoMedia&players=Download,RTMP");

  my $xml = from_xml($browser->content, NoAttr => 1);

  my $video = $xml->{"Videos"}->{"Video"};

  my $medias = $video->{"VideoMedias"}->{"VideoMedia"};
  my $media = @$medias[0];

#  my $max = 0;
#  my $max = (grep { $max = ((int($_->{Width}) * int($_->{Height})) gt $max ? $_ : $max) } @$medias);
#  foreach (@{$video->{VideoMedias}->{VideoMedia}}) {
#    debug $_;
#    debug int($_->{Width}) * int($_->{Height});
#  }
#  debug $max;
#  my $media = (grep { (int($_->{Width}) * int($_->{Height})) eq $max } $medias)[0];
  my $delivery_url = $media->{DeliveryUrl};
  debug $delivery_url;

  my $title = $video->{FranchiseName} . ' - ' . $video->{Title};
  debug $title;

  return {
    rtmp => $delivery_url,
    flv => title_to_filename($title)
  };
}

1;

