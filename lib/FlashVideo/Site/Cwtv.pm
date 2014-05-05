# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Cwtv;

use strict;
use FlashVideo::Utils;
use FlashVideo::JSON;

our $VERSION = '0.01';
sub Version() { $VERSION; }

sub find_video {
  my($self, $browser, $embed_url, $prefs) = @_;

  # Extract player configuration URL and media key
  my ($vs_swf_url, $vs_config_url, $mediakey);
  if ( $browser->content =~ /(http.*?)\/(vsplayer\.swf)/ ) {
    $vs_swf_url = "$1/$2";
    $vs_config_url = "$1/vsplayer.xml";
  } else {
    die "Could not find vsplayer URL! " . $browser->uri->as_string;
  }
  if ( $browser->content =~ /MediaKey[^a-z0-9]*([-a-f0-9]{36})[^a-z0-9]/i ) {
    $mediakey = $1;
  } else {
    die "Could not find media key! " . $browser->uri->as_string;
  }
  print "Media key is $mediakey\n";

  # Fetch player configuration to get MFS URL
  $browser->get($vs_config_url);
  if (!$browser->success) {
    die "Couldn't download vsplayer config $vs_config_url: " .
        $browser->response->status_line;
  }
  my $xml = from_xml($browser);
  my $mfsurl = join('/', $xml->{mfs}->{mfsUrl}, $xml->{mfs}->{mfsVersion},
                    $xml->{mfs}->{mfsAccount}, 'assets', $mediakey,
                    'partner', $xml->{mfs}->{mfsPartnerId}) . '?format=json';

  # Fetch MFS URL to get RTMP URLs
  $browser->get($mfsurl);
  if (!$browser->success) {
    die "Couldn't download MFS URL $mfsurl: " . $browser->response->status_line;
  }
  my $json = from_json($browser->content);

  # Select a video to play
  my @types = keys %{$json->{videos}};
  @types = sort { $json->{videos}->{$a}->{bitrate} <=>
                      $json->{videos}->{$b}->{bitrate} } @types;
  my $quality = $prefs->{quality};
  if ( !exists($json->{videos}->{$quality}) ) {
    $quality = $types[$quality eq 'high' ? -1 :
                      ($quality eq 'low' ? 0 : int($#types/2))];
  }
  print "Using quality $quality\n";
  my $item = $json->{videos}->{$quality};

  # Parse the URL
  my ($rtmp, $playpath);
  if ( $item->{uri} =~ /^(rtmpe?:.*\/)([a-z0-9]+:.+)$/ ) {
    $rtmp = $1;
    $playpath = $2;
  }
  else {
    die "Couldn't parse stream URI: $item->{uri}";
  }

  # Format the output filename
  my $metadata = $json->{assetFields};
  my $title = sprintf('%s-S%02dE%02d-%s', $metadata->{seriesName},
                      $metadata->{seasonNumber}, $metadata->{episodeNumber},
                      $metadata->{title});
  my $filename = title_to_filename($title);

  # Subtitles might be available
  if ($prefs->{subtitles}) {
    my $ttmlurl = $metadata->{UnicornCcUrl};
    $browser->get($metadata->{UnicornCcUrl}) if $ttmlurl;
    if ( $ttmlurl && $browser->success ) {
      my $srtfile = title_to_filename($title, 'srt');
      convert_ttml_subtitles_to_srt($browser->content, $srtfile);
      info "Saved subtitles to $srtfile";
    }
    else {
      warn "Couldn't download subtitles $ttmlurl: " .
          $browser->response->status_line;
    }
  }

  return {
    flv => $filename,
    playpath => $playpath,
    rtmp => $rtmp,
    swfUrl => $vs_swf_url,
    pageUrl => 'http://cwtv.com',
  };
}

1;
