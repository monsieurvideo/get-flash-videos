# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Tv3play;
use strict;
use warnings;
use FlashVideo::Utils;

our $VERSION = '0.02';
sub Version() { $VERSION;}

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;
  return $self->find_video_viasat($browser,$embed_url,$prefs);
}

sub find_video_viasat {
  my ($self, $browser, $embed_url, $prefs) = @_;
  my $video_id = ($browser->content =~ /data-video-id="([0-9]*)"/)[0];
  info "Got video_id: $video_id";
  my $info_url = "http://viastream.viasat.tv/PlayProduct/$video_id";
  $browser->get($info_url);

  my $xml = from_xml($browser->content);
  my $product = $xml->{Product};
  my $title = $product->{Title};
  my $flv_filename = title_to_filename($title, "flv");

  # Create array of video resolutions
  my @videos;
  if (ref $product->{Videos} eq 'HASH') {
    push(@videos, $product->{Videos});
  } else {
    @videos = $product->{Videos};
  }

  # Collect the rtmp data for each resolution
  my @urls;
  foreach (@videos) {
    my $video = $_->{Video};
    my $bitrate = $video->{BitRate};
    my $url = $video->{Url};

    if ($url =~ m/http:\/\//){
      $browser->get($url);
      $xml = from_xml($browser->content);
      $url = $xml->{'Url'};
    }

    my $rtmp_data = {
      'swfVfy' => "http://flvplayer.viastream.viasat.tv/flvplayer/play/swf/MTGXPlayer-0.7.4.swf",
      'flv'    => $flv_filename
    };

    if ($url =~ /(rtmp:.*)(mp4:.*)/) {
      $rtmp_data->{'rtmp'} = $1;
      $rtmp_data->{'playpath'} = $2;
    } else {
      $rtmp_data->{'rtmp'} = $url;
    }

    push(@urls, { 'bitrate' => $bitrate, 'rtmp_data' => $rtmp_data });
  }

  my $bitrate = 0;
  my $new_bitrate;
  my $rtmp_data;
  foreach (@urls) {
    $new_bitrate = int($_->{bitrate});
    if ($new_bitrate > $bitrate) {
      $bitrate = int($_->{bitrate});
      $rtmp_data = $_->{rtmp_data};
    }
  };

  return $rtmp_data;
}

1;
