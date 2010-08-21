# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Bbc;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $page_url) = @_;

  # Get playlist XML
  my $playlist_xml;
  if ($browser->content =~ /<param name="playlist" value="(http:.+?\.xml)"/) {
    $playlist_xml = $1;
  }
  elsif($browser->content =~ /empDivReady\s*\(([^)]+)/) {
    my @params = split /,\s*/, $1;

    my $id   = $params[3];
    my $path = $params[4];

    $id   =~ s/['"]//g;
    $path =~ s/['"]//g;

    $playlist_xml = URI->new_abs($path, $browser->uri) . "/media/emp/playlists/$id.xml";
  }
  elsif($browser->content =~ /setPlaylist\s*\(([^)]+)/) {
    my $path = $1;
    $path =~ s/['"]//g;
    $playlist_xml = URI->new_abs($path, $browser->uri);
  }
  elsif($browser->content =~ /EmpEmbed.embed\s*\((.*?)\);/) {
    my $path = (split /,/, $1)[3];
    $path =~ s/"//g;
    $playlist_xml = URI->new_abs($path, $browser->uri);
  }
  elsif($browser->uri =~ m!/(b[0-9a-z]{7})(?:/|$)!) {
    # Looks like a pid..
    my @gi_cmd = (qw(get_iplayer -g --pid), $1);

    if($browser->content =~ /buildAudioPlayer/) {
      # Radio programme
      push @gi_cmd, "--type=radio";
    }

    error "get_flash_videos does not support iplayer, but get_iplayer does..";
    info "Attempting to run '@gi_cmd'";
    exec @gi_cmd;
    # Probably not installed..
    error "Please download get_iplayer from http://linuxcentre.net/getiplayer/\n" .
      "and install in your PATH";
    exit 1;
  }
  else {
    die "Couldn't find BBC XML playlist URL in " . $browser->uri->as_string;
  }

  $browser->get($playlist_xml);
  if (!$browser->success) {
    die "Couldn't download BBC XML playlist $playlist_xml: " .
      $browser->response->status_line;
  }

  my $playlist = eval { from_xml($browser, KeyAttr => {item => 'kind'}) };

  if ($@) {
    # Try to fix their potentially broken XML..
    my $content = $browser->content;
    if ($content !~ m{</media>}) {
      $content .= "\n</media></item></playlist>\n";
    }
    $playlist = from_xml($$content, KeyAttr => {item => 'kind'})
  }

  my $sound = ($playlist->{item}->{guidance} !~ /has no sound/);

  my $info = ref $playlist->{item}->{media} eq 'ARRAY'
    ? $playlist->{item}->{media}->[0]->{connection}
    : $playlist->{item}->{media}->{connection};

  $info = $playlist->{item}->{programme}->{media}->{connection} unless $info;

  $info->{application} ||= "ondemand";

  # Different method for retrieving some BBC videos, for example:
  #   http://news.bbc.co.uk/sport1/hi/motorsport/formula_one/8766344.stm
  if (!$info->{server}) {
    my $id = $playlist->{item}->{mediator}->{identifier};

    my $stream_info_url = sprintf
      "http://open.live.bbc.co.uk/mediaselector/4/mtis/stream/%s", $id;

    $browser->back();
    $browser->get($stream_info_url);

    if (!$browser->success) {
      die "Couldn't get BBC stream info URL: " .
        $browser->response->status_line;
    }

    my $stream_info = from_xml($browser->content);

    $info = ref $stream_info->{media} eq 'ARRAY'
      ? $stream_info->{media}->[0]->{connection}
      : $stream_info->{media}->{connection};
  }

  my $data = {
    app      => $info->{application},
    tcUrl    => "rtmp://$info->{server}/$info->{application}",
    swfUrl   => "http://news.bbc.co.uk/player/emp/2.11.7978_8433/9player.swf",
    pageUrl  => $page_url,
    rtmp     => "rtmp://" .  $info->{server} . "/$info->{application}",
    playpath => $info->{identifier},
    flv      => title_to_filename('BBC - ' . $playlist->{title} .
                                ($sound ? '' : ' (no sound)'))
  };

  # Different kind of 'secure' video. The auth string (or token) is already
  # provided in the XML. The auth string actually includes other RTMP
  # parameters as well - unlike in the case below, it's not just the actual
  # token.
  if ($info->{authString}) {
    my $token = $info->{authString};

    $data->{app} = "$info->{application}?_fcs_vhost=$info->{server}" .
                   "&$token";
                    
    $data->{tcUrl} = "rtmp://$info->{server}/$info->{application}?_fcs_vhost=$info->{server}"
            . "&$token";

    $data->{playpath} .= "?$token";
  }

  # 'Secure' items need to be handled differently - have to get a token to
  # pass to the rtmp server.
  if ($info->{identifier} =~ /^secure/ or $info->{tokenIssuer}) {
    my $url = "http://www.bbc.co.uk/mediaselector/4/gtis?server=$info->{server}" .
              "&identifier=$info->{identifier}&kind=$info->{kind}" .
              "&application=$info->{application}&cb=123";

    debug "Got BBC auth URL for 'secure' video: $url";

    $browser->get($url);

    # BBC redirects us to the original URL which is odd, but oh well.
    if (my $redirect = $browser->response->header('Location')) {
      debug "BBC auth URL redirects to: $url";
      $browser->get($redirect);
    }

    my $stream_auth = from_xml($browser);

    my $token = $stream_auth->{token};

    if (!$token) {
      die "Couldn't get token for 'secure' video download";
    }

    $data->{app} = "$info->{application}?_fcs_vhost=$info->{server}"
            . "&auth=$token"
            . "&aifp=v001&slist=" . $info->{identifier};
    $data->{tcUrl} = "rtmp://$info->{server}/$info->{application}?_fcs_vhost=$info->{server}"
            . "&auth=$token"
            . "&aifp=v001&slist=" . $info->{identifier};
    $data->{playpath} .= "?auth=$token&aifp=v0001";

    if($info->{application} eq 'live') {
      $data->{subscribe} = $data->{playpath};
      $data->{live} = 1;
    }
  }

  return $data;
}

1;
