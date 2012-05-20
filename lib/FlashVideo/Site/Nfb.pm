# Part of get-flash-videos. See get_flash_videos for copyright.
# Except the CCR bits, thanks to Fogerty for those.
package FlashVideo::Site::Nfb;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;

  # get the flash player url to use as the referer and the url of the config file
  my($refer, $cURL) = $browser->content =~ /<link rel="video_src" href="([^?]+)\?configURL=([^&]+)&/;

  # get the config file with the stream info
  $browser->post(
    $cURL,
    "X-NFB-Referer" => $refer,
    Content_Type => "application/x-www-form-urlencoded",
    Content => "getConfig=true",
  );

  if (!$browser->success) {
    die "Getting config info failed: " . $browser->response->status_line();
  }

  my $xml = from_xml($browser->content);

  # find the video stream info
  my $media;
  foreach (@{$xml->{player}->{stream}->{media}}) {
    if ($_->{"type"} eq "video") {
      $media = $_;
      last;
    }
  }

  my $title = $media->{title};

  # The video might be available in different qualities. Try to download the 
  # highest quality by default. Qualities in descending order: M1M, M415K, M48K.

  my @assets = sort { _get_quality_from_url($b->{default}->{url}) <=> _get_quality_from_url($a->{default}->{url}) }
                    (@{$media->{assets}->{asset}});

  if (!@assets) {
    die "Couldn't find any streams in the config file";
  }

  my $quality = $prefs->{quality};
  my $asset;
  if ($quality eq "high") {
    $asset = $assets[0];
  } elsif ($quality eq "low") {
    $asset = $assets[-1];
  } elsif ($quality eq "medium") {
    if (scalar(@assets) > 1) {
      $asset = $assets[1];
    } else {
      $asset = $assets[0];
    }
  } else {
    die "Unknown quality setting";
  }

  my $rtmp_url = $asset->{default}->{streamerURI};
  my($host, $app) = $rtmp_url =~ m'rtmp://([^/]+)/(\w+)';
  my $playpath = $asset->{default}->{url};

  return {
    flv => title_to_filename($title),
    rtmp => $rtmp_url,
    app => $app,
    playpath => $playpath
  };
}

sub _get_quality_from_url {
  my($url) = @_;

  if ($url =~ m'/streams/[A-Z](\d+)([A-Z])') {
    my ($size, $units) = ($1, $2);

    $size *= 1024 if $units eq 'M';

    return $size;
  }
}

1;
