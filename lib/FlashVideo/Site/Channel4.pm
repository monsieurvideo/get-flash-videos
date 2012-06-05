# Part of get-flash-videos. See get_flash_videos for copyright.
# Thanks to Nibor for his XBMC 4od plugin - this is largely a Perl port of
# it.
package FlashVideo::Site::Channel4;

use strict;

use Crypt::Blowfish_PP;
use FlashVideo::Utils;
use MIME::Base64;

use constant TOKEN_DECRYPT_KEY => 'STINGMIMI';

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;

  my $page_url = $browser->uri->as_string;

  # Determine series and episode. Channel 4 sometimes have these backwards,
  # but as long as they differ there's less risk of overwriting or
  # incorrectly resuming previous episodes from the same series.
  my $series_and_episode;
  if ($browser->content =~ /<meta\ property="og:image"
                            \ content="\S+series-(\d+)\/episode-(\d+)/x) {
    $series_and_episode = sprintf "S%02dE%02d", $1, $2;
  }

  # get SWF player file
  my $swf_player;
  if ($browser->content =~ /fourodPlayerFile\s+=\s+\'(4od\S+\.swf)\'/i) {
    $swf_player = $1;
  }
  else {
     $swf_player = '4odplayer-11.21.2.swf';
  }

  # Get asset ID from 4od programme URL, which can be in two different
  # formats:
  #
  #   http://www.channel4.com/programmes/dispatches/4od#3220372
  #   http://www.channel4.com/programmes/dispatches/4od/player/3269465
  my $asset_id;

  if ($page_url =~ m'(?:4od/player/|4od[^\/]*#)(\d+)') {
    $asset_id = $1;
  }
  else {
    die "Can't get asset ID";
  }

  # Get programme XML.
  my $raw_xml = $browser->get("http://ais.channel4.com/asset/$asset_id");

  if (!$browser->success) {
    die "Couldn't get asset XML: " . $browser->status_line;
  }

  my $xml = from_xml($raw_xml);

  my $stream_url = $xml->{assetInfo}->{uriData}->{streamUri};
  my $token      = $xml->{assetInfo}->{uriData}->{token};
  my $cdn        = $xml->{assetInfo}->{uriData}->{cdn};

  my $decoded_token = decode_4od_token($token);

  # RTMP authentication - varies depending on which CDN is in use.
  my $auth;

  # Different CDNs require different handling.
  if ($cdn eq 'll') {
    # Limelight
    my $ip = $xml->{assetInfo}->{uriData}->{ip};
    my $e  = $xml->{assetInfo}->{uriData}->{e};

    if (defined $ip) {
      $auth = sprintf "e=%s&ip=%s&h=%s", $e, $ip, $decoded_token;
    }
    else {
      $auth = sprintf "e=%s&h=%s", $e, $decoded_token;
    }
  }
  else {
    # Akamai presumably
    my $fingerprint = $xml->{assetInfo}->{uriData}->{fingerprint};
    my $slist       = $xml->{assetInfo}->{uriData}->{slist};

    $auth = sprintf "auth=%s&aifp=%s&slist=%s",
      $decoded_token, $fingerprint, $slist;
  }

  # Get filename to use.
  my $title;
  my @title_components = grep defined,
                         map { $xml->{assetInfo}->{$_} }
                         qw(brandTitle episodeTitle);

  if ($series_and_episode) {
    push @title_components, $series_and_episode;
  }

  if (@title_components) {
    $title = join " - ", @title_components;
  }
  
  my $filename = title_to_filename($title, "mp4");

  # Get subtitles if necessary.
  if ($prefs->subtitles) {
    if (my $subtitles_url = $xml->{assetInfo}->{subtitlesFileUri}) {
      $subtitles_url = "http://ais.channel4.com$subtitles_url";
      
      $browser->get($subtitles_url);

      if (!$browser->success) {
        info "Couldn't download 4od subtitles: " . $browser->status_line;
      }

      my $subtitles_file = title_to_filename($title, "srt");
      convert_sami_subtitles_to_srt($browser->content, $subtitles_file); 

      info "Saved subtitles to $subtitles_file";
    }
    else {
      debug("Subtitles requested for '$title' but none available.");
    }
  }

  # Create the various options for rtmpdump.
  my $rtmp_url;
  
  if ($stream_url =~ /(.*?)mp4:/) {
    $rtmp_url = $1;
  }

  $rtmp_url =~ s{\.com/}{.com:1935/};
  $rtmp_url .= "?ovpfv=1.1&$auth";
  
  my $app;
  if ($stream_url =~ /.com\/(.*?)mp4:/) {
    $app = $1;
    $app .= "?ovpfv=1.1&$auth";
  }

  my $playpath;
  if ($stream_url =~ /.*?(mp4:.*)/) {
    $playpath = $1;
    $playpath .= "?$auth";
  }

  # swf url could be relocated, url_exists returns relocated url.
  my $swf_player_url = url_exists($browser, "http://www.channel4.com/static/programmes/asset/flash/swf/$swf_player");
  if ($swf_player_url == '') {
     die "swf url not found";

  }
  
  return {
    flv      => $filename,
    rtmp     => $rtmp_url,
    flashVer => '"WIN 11,0,1,152"',
    swfVfy   => "$swf_player_url",
    conn     => 'Z:',
    playpath => $playpath,
    pageUrl  => $page_url,
    app      => $app,
  };
}

sub decode_4od_token {
  my $encrypted_token = shift;

  $encrypted_token = decode_base64($encrypted_token);

  my $blowfish = Crypt::Blowfish_PP->new(TOKEN_DECRYPT_KEY);

  my $decrypted_token = '';

  # Crypt::Blowfish_PP only decrypts 8 bytes at a time.
  my $position = 0;

  while ( $position < length $encrypted_token) {
    $decrypted_token .= $blowfish->decrypt(substr $encrypted_token, $position, 8);
    $position += 8;
  }

  # remove padding.. PKCS7/RFC5652..
  my $npad = unpack("c", substr($decrypted_token, -1));
  if ($npad > 0 && $npad < 9) {
    $decrypted_token = substr($decrypted_token, 0, length($decrypted_token)-$npad);
  }
  return $decrypted_token;
}

1;
