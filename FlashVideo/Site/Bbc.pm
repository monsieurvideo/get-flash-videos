# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Bbc;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser) = @_;

  my $has_xml_simple = eval { require XML::Simple };
  if(!$has_xml_simple) {
    die "Must have XML::Simple installed to download BBC videos";
  }

  # Get playlist XML
  my $playlist_xml;
  if ($browser->content =~ /<param name="playlist" value="(http:.+?\.xml)"/) {
    $playlist_xml = $1;
  }
  else {
    die "Couldn't find BBC XML playlist URL in " . $browser->uri->as_string;
  }

  $browser->get($playlist_xml);
  if (!$browser->success) {
    die "Couldn't download BBC XML playlist $playlist_xml: " .
      $browser->status_line;
  }

  my $playlist = eval {
    XML::Simple::XMLin($browser->content)
  };

  if ($@) {
    die "Couldn't parse BBC XML playlist: $@";
  }

  my $app   = $playlist->{item}->{media}->{connection}->{application};
  my $tcurl = "rtmp://" .  $playlist->{item}->{media}->{connection}->{server} .
              "/$app";
  my $rtmp  = "rtmp://" .  $playlist->{item}->{media}->{connection}->{server} .
              "/?slist=" .  $playlist->{item}->{media}->{connection}->{identifier};
              # (Note slist is an rtmpdump weirdism)
  my $sound = ($playlist->{item}->{guidance} !~ /has no sound/);
  my $flv   = title_to_filename('BBC - ' . $playlist->{title} .
                                ($sound ? '' : ' (no sound)'));

  # 'Secure' items need to be handled differently - have to get a token to
  # pass to the rtmp server.
  my $swfurl;
  if ($playlist->{item}->{media}->{connection}->{identifier} =~ /^secure/) {
    my $info = $playlist->{item}->{media}->{connection};

    my $url = "http://www.bbc.co.uk/mediaselector/4/gtis?server=$info->{server}" .
              "&identifier=$info->{identifier}&kind=$info->{kind}" .
              "&application=$info->{application}&cb=123";

    print STDERR "Got BBC auth URL for 'secure' video: $url\n";

    $browser->get($url);

    # BBC redirects us to the original URL which is odd, but oh well.
    if (my $redirect = $browser->response->header('Location')) {
      print STDERR "BBC auth URL redirects to: $url\n";
      $browser->get($redirect);
    }

    my $stream_auth = eval {
      XML::Simple::XMLin($browser->content);
    };

    if ($@) {
      die "Couldn't parse BBC stream auth XML for 'secure' stream.\n" .
          "XML is apparently:\n" .
          $browser->content() . "\n" .
          "XML::Simple said: $@";
    }

    my $token = $stream_auth->{token};

    if (!$token) {
      die "Couldn't get token for 'secure' video download";
    }

    $app = "ondemand?_fcs_vhost=$info->{server}"
            . "&auth=$token"
            . "&aifp=v001&slist=" . $info->{identifier};
    $tcurl = "rtmp://$info->{server}:80/$app";
    $rtmp  = "rtmp://$info->{server}:1935/ondemand?_fcs_vhost="
            . $info->{server} . "&aifp=v001" .
              "&slist=" . $info->{identifier};
    $swfurl = " --swfUrl 'http://www.bbc.co.uk/emp/9player.swf?revision=7978_8340'";
  }

  return "rtmpdump -o '$flv' --app '$app' --tcUrl '$tcurl' --rtmp '$rtmp' $swfurl ";
}

1;
