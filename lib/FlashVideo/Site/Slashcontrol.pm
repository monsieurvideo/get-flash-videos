# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Slashcontrol;

use strict;
use FlashVideo::Utils;
use FlashVideo::JSON;

sub find_video {
  my($self, $browser, $embed_url, $prefs) = @_;

  my $config;
  my $mediaKey;
  if ($browser->content =~ /<param name="flashvars" value="config=([^&]*)&mediaKey=([^"]*)"\/>/) {
    $config = $1;
    $mediaKey = $2;
  } else {
    die "Couldn't find flashvars param in " . $browser->uri->as_string;
  }
  my $root;
  if ($browser->content =~ /<embed src="(.*)\/[^\/]*\.swf"/) {
    $root = $1;
  } else {
    die "Couldn't find embeded swf " . $browser->uri->as_string;
  }
  my $config_url;
  $config_url = $1 . "/" . $config;

  $browser->allow_redirects;
  $browser->get($config_url);
  if (!$browser->success) {
    die "Couldn't download config.xml $config_url: " . $browser->response->status_line;
  }

  my $xml = from_xml($browser);
  my $domain = $xml->{mfs}->{mfsUrl};
  my $version = $xml->{mfs}->{mfsVersion};
  my $account = $xml->{mfs}->{mfsAccount};
  my $partner = $xml->{mfs}->{mfsPartnerId};

  my $asset_url = "$domain/$version/$account/assets/$mediaKey/partner/$partner?format=json";
  $browser->get($asset_url);
  if (!$browser->success) {
    die "Couldn't download asset file $asset_url: " . $browser->response->status_line;
  }

  my $asset_data = from_json($browser->content);
  my $videos = $asset_data->{videos};

  my $title = title_to_filename($asset_data->{assetFields}->{seriesName} . " - " . $asset_data->{assetFields}->{title});

#  my $video = (grep { $_->{scheme} eq "" } $videos)[0]
  my $video = $videos->{limelight700};
#  my $max_bitrate = 0;
#  while (($key, $value) = each ($videos))
#    if (int($value->{bitrate}) > $max_bitrate) {
#      $video = $value;
#      $max_bitrate = int($value->{bitrate});
#    }
#  }

  my $rtmp = $video->{uri};

  return {
    flv => $title,
    rtmp => $rtmp,
  };
}

1;
