# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Channel4;

use strict;
use FlashVideo::Utils;
use URI::Escape;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my $has_xml_simple = eval { require XML::Simple };
  if(!$has_xml_simple) {
    die "Must have XML::Simple installed to download Channel4/4oD videos";
  }

  my $page_url = $browser->uri->as_string;

  my $asset_number;
  if($page_url =~ /catch-up#(\d+)/) {
    $asset_number = $1;
  } else {
    die "Couldn't get Channel 4 asset number";
  }

  my $metadata_url = URI->new(
    'http://www.channel4.com/services/catchup-availability/asset-info/'
    . $asset_number . '?' . time);
  my $host = $metadata_url->host;
  my $path = $metadata_url->path_query;

  my $request = join "\r\n",
    "GET $path HTTP/1.1",
    "Host: $host",
    "User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-GB; rv:1.9.0.1) Gecko/2008072820 Firefox/3.0.1",
    "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language: en-gb,en;q=0.5",
    "Accept-Encoding: gzip,deflate",
    "Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7",
    "Connection: close",
    "\r\n";

  my $sock = IO::Socket::INET->new(PeerAddr => $host, PeerPort => 80) or die $!;
  print $sock $request;

  my $response = HTTP::Response->parse(join '', <$sock>);

  if(!$response->is_success) {
    error "Couldn't download: " . $response->status_line;
    error "Content:\n" . $response->content;
  }

  return _process_xml($browser, $response->content);
}

sub _process_xml {
  my($browser, $xml_string) = @_;

  $xml_string =~ s/(?:\r\n)?\s*[a-f0-9]{1,5}\r\n//igm;
  $xml_string =~ s/^\s*//s;

  debug $xml_string;

  my $xml = eval { XML::Simple::XMLin($xml_string) };
  die "Couldn't parse XML: $@" if $@;

  my($server, $app, $playpath);
  my $uriData = $xml->{assetInfo}->{uriData};

  if($uriData->{streamUri} =~ m{rtmpe://([^/]+)/\w+/(.*)}) {
    $server = $1;
    $playpath = $2;
  }

  my $app = "ondemand?_fcs_vhost=$server&ovpfv=1.1&auth=$uriData->{token}&"
    . "aifp=$uriData->{fingerprint}&slist=$uriData->{slist}";

  $server = Socket::inet_ntoa(scalar gethostbyname($server));
  my $url = "rtmpe://$server:1935/$app";

  my $filename = _generate_filename($xml->{assetInfo});

  return {
    app      => $app,
    playpath => $playpath,
    tcUrl    => $url,
    auth     => $uriData->{token},
    rtmp     => $url,
    pageUrl  => (split /#/, $browser->uri->as_string)[0],
    flv      => $filename,

    swfhash($browser,
      "http://www.channel4.com/static/programmes/asset/flash/swf/4odplayer-4.3.2.swf"),
  };
}

sub _generate_filename {
  my($asset) = @_;

  my $title = $asset->{brandTitle};
  if($title =~ /\Q$asset->{episodeTitle}\E/i) {
    $title = $asset->{episodeTitle};
  } else {
    $title .= " - $asset->{episodeTitle}";
  }

  my $episode = "";
  if($asset->{seriesNumber}) {
    $episode = sprintf "S%02d", $asset->{seriesNumber};
  }

  if($asset->{episodeNumber}) {
    $episode .= sprintf "E%02d", $asset->{episodeNumber};
  }

  $title .= " - $episode" if $episode;

  return title_to_filename($title);
}

1;

