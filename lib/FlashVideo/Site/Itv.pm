# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Itv;

use strict;
use FlashVideo::Utils;
use FlashVideo::JSON;
use HTML::Entities;
use Encode;
use Data::Dumper;

our $VERSION = '0.09.02';
sub Version() { $VERSION;}

sub extract_attributes {
  my $substr = shift;

  my %attrib;
  while ($substr =~ m/([-a-z0-9]+)\s*=\"([^\"]+)\"/gi) {
    $attrib{$1} = $2;
  }
  return \%attrib;
}

sub find_video {
  my ($self, $browser, $page_url, $prefs) = @_;

  my($id) = $browser->uri =~ /Filter=(\d+)/;

  
  my ($itv_param_str) = $browser->content =~ /(\<[^\<]+id="video"[^\>]*\>)/;
#  info "substring $itv_param_str";
  my $itv_params = extract_attributes($itv_param_str);
#  info " test ".$itv_params->{'data-video-autoplay-id'};
#  info " test ".$itv_params->{'data-video-episode-id'};
#  info " test ".$itv_params->{'data-playlist-url'};

  my ($og_title) = $browser->content =~ /\<meta\s+property\s*=\s*"og:title"\s+content\s*=\"([^\"]+)\"\>/;
  


  my $productionid;
  ($productionid) = $browser->content =~ /\"productionId\":\"([^\"]+)\"/i;
  if (! $productionid) {
    ($productionid) = $browser->content =~ / data-video-id\s*=\s*\"([^\"]+)\"/i;
  }
  $productionid =~ s%^.*/%%;
  $productionid =~ tr%_\.%/#%;
  debug "Production ID $productionid\n";
  die "No id (filter) found in URL or production id\n" unless $productionid;

  my $hls_dl= 1;
  my $rtmp_dl = 1;
  if ($prefs->{type} =~ /hls/) {
    $rtmp_dl = 0;
  }
  if ($prefs->{type} =~ /rtmp/) {
    $hls_dl = 0;
  }

  if ( $id && $rtmp_dl)
  {

    $browser->post("http://mercury.itv.com/PlaylistService.svc",
      Content_Type => "text/xml; charset=utf-8",
      Referer      => "http://www.itv.com/mercury/Mercury_VideoPlayer.swf?v=1.5.309/[[DYNAMIC]]/2",
      SOAPAction   => '"http://tempuri.org/PlaylistService/GetPlaylist"',
      Content      => <<EOF);
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <SOAP-ENV:Body>
    <tem:GetPlaylist xmlns:tem="http://tempuri.org/" xmlns:itv="http://schemas.datacontract.org/2004/07/Itv.BB.Mercury.Common.Types" xmlns:com="http://schemas.itv.com/2009/05/Common">
      <tem:request>
        <itv:RequestGuid>FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF</itv:RequestGuid>
        <itv:Vodcrid>
          <com:Id>$id</com:Id>
          <com:Partition>itv.com</com:Partition>
        </itv:Vodcrid>
      </tem:request>
      <tem:userInfo>
        <itv:GeoLocationToken>
          <itv:Token/>
        </itv:GeoLocationToken>
        <itv:RevenueScienceValue>scc=true; svisit=1; sc4=Other</itv:RevenueScienceValue>
      </tem:userInfo>
      <tem:siteInfo>
        <itv:AdvertisingRestriction>None</itv:AdvertisingRestriction>
        <itv:AdvertisingSite>ITV</itv:AdvertisingSite>
        <itv:Area>ITVPLAYER.VIDEO</itv:Area>
        <itv:Platform>DotCom</itv:Platform>
        <itv:Site>ItvCom</itv:Site>
      </tem:siteInfo>
    </tem:GetPlaylist>
  </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
EOF

    debug $browser->content;
  }
  elsif ($rtmp_dl) {
    $browser->post($itv_params->{'data-playlist-url'},
      Content_Type => "text/xml; charset=utf-8",
      Referer      => "http://www.itv.com/mercury/Mercury_VideoPlayer.swf?v=1.5.309/[[DYNAMIC]]/2",
      SOAPAction   => '"http://tempuri.org/PlaylistService/GetPlaylist"',
      Content      => <<EOF);
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tem="http://tempuri.org/" xmlns:itv="http://schemas.datacontract.org/2004/07/Itv.BB.Mercury.Common.Types" xmlns:com="http://schemas.itv.com/2009/05/Common">
  <soapenv:Header/>
  <soapenv:Body>
    <tem:GetPlaylist>
      <tem:request>
        <itv:ProductionId>$productionid</itv:ProductionId>
        <itv:RequestGuid>FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF</itv:RequestGuid>
        <itv:Vodcrid>
          <com:Id/>
          <com:Partition>itv.com</com:Partition>
        </itv:Vodcrid>
      </tem:request>
      <tem:userInfo>
        <itv:Broadcaster>Itv</itv:Broadcaster>
        <itv:GeoLocationToken>
          <itv:Token/>
        </itv:GeoLocationToken>
        <itv:RevenueScienceValue>ITVPLAYER.12.18.4</itv:RevenueScienceValue>
        <itv:SessionId/>
        <itv:SsoToken/>
        <itv:UserToken/>
      </tem:userInfo>
      <tem:siteInfo>
        <itv:AdvertisingRestriction>None</itv:AdvertisingRestriction>
        <itv:AdvertisingSite>ITV</itv:AdvertisingSite>
        <itv:AdvertisingType>Any</itv:AdvertisingType>
        <itv:Area>ITVPLAYER.VIDEO</itv:Area>
        <itv:Category/>
        <itv:Platform>DotCom</itv:Platform>
        <itv:Site>ItvCom</itv:Site>
      </tem:siteInfo>
      <tem:deviceInfo>
        <itv:ScreenSize>Big</itv:ScreenSize>
      </tem:deviceInfo>
      <tem:playerInfo>
        <itv:Version>2</itv:Version>
      </tem:playerInfo>
    </tem:GetPlaylist>
  </soapenv:Body>
</soapenv:Envelope>
EOF

    debug $browser->content;
  }
  # We want the RTMP url within a <Video timecode=...> </Video> section.


  if ( $hls_dl && (! $rtmp_dl || ($rtmp_dl && 
        $browser->content =~ m%<faultcode>InvalidEntity</faultcode>%) ) ) {

    debug "Trying IOS download...";
    debug "Title: $og_title";
    debug "Episode Title ".$itv_params->{'data-video-episode'};
    debug "Series: ".$itv_params->{'data-video-title'};

    my $ios_playlist_url = $itv_params->{'data-video-playlist'};
    my $hmac = $itv_params->{'data-video-hmac'};

    if ( ! defined($ios_playlist_url)) {
        $ios_playlist_url = $itv_params->{'data-video-id'};
    }

    debug "ios url: $ios_playlist_url";
    debug "hamc: $hmac";
    my $hls_m3u = 'https://127.0.0.1/test.m3u';
    
    $browser->agent('Mozilla/5.0 (X11; Linux x86_64; rv:10.0) Gecko/20150101 Firefox/47.0 (Chrome)');

    $browser->post($ios_playlist_url, 
      Content_Type => 'application/json',
      Accept       => 'application/vnd.itv.vod.playlist.v2+json',
      Accept_Encoding => 'gzip, deflate',
      X_Forwarded_For => '25.166.199.253',
      hmac => uc($hmac),
      Content      => '{"user": {"itvUserId": "", "entitlements": [], "token": ""}, "device": {"manufacturer": "Safari", "model": "5", "os": {"name": "Windows NT", "version": "6.1", "type": "desktop"}}, "client": {"version": "4.1", "id": "browser"}, "variantAvailability": {"featureset": {"min": ["hls", "aes", "outband-webvtt"], "max": ["hls", "aes", "outband-webvtt"]}, "platformTag": "dotcom"}}');
 
    debug $browser->content;
    my $playlist = from_json($browser->content);
    my $video_id = $playlist->{Playlist}->{Video};
    my $base_url = $video_id->{Base};
    my @media_files = @{$video_id->{MediaFiles}};

    debug Data::Dumper::Dumper(@media_files);
    foreach my $media_file (@media_files) {
      debug Data::Dumper::Dumper($media_file);
      $hls_m3u = $base_url . $media_file->{Href};
    }
    my $file_id = $productionid;
    $file_id =~ tr%_/#%---%;
    my $filename = title_to_filename("$file_id\_$og_title\_hls", "mp4");
    debug "filename: $filename";

    $browser->cookie_jar( {} ); # keep cookies
    $browser->add_header( Referer => undef);
    $browser->delete_header( 'Referer' );
    $browser->add_header( Accept => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');
    $browser->add_header( Accept_Encoding => 'gzip, deflate');
    $browser->add_header( Accept_Language => 'en-us,en;q=0.5');
    $browser->add_header( X_Forwarded_For => '25.166.199.253');

    return {
      downloader => "hlsx",
      flv        => $filename,
      args       => { hls_url => $hls_m3u, prefs => $prefs }
    };
  }
  die "Unable to find <Video> in XML" unless $browser->content =~ m{<Video timecode[^>]+>(.*?)</Video>}s;
  my $video = $1;

  # Parse list of availible formats and lookup their resolutions

  my %formats;

  my $progtitle;
  my $eptitle;
  if ($browser->content =~ m%<ProgrammeTitle>(.*?)</ProgrammeTitle>% ) {
    $progtitle = $1;
    $progtitle =~ s/\W+/-/g;
  }
  if ( $browser->content =~ m%<EpisodeTitle>(.*?)</EpisodeTitle%) {
    $eptitle = $1;
    $eptitle =~ s/\W+/-/g;
  }

# Normal format for catchup service
  while ($video =~ m/(mp4:[^\]]+_[A-Z]+([0-9]{3,4})(|_[^\]]+)_(16|4)[-x](9|3)[^\]]*.mp4)/gi)
  {
    $formats{$2} = { video => $video, playpath => $1, ratio => "$4x$5" };
  }

  while ($video =~ m/(mp4:[^\]]+_PC01([0-9]{3,4})(|_[^\]]+)_(16|4)[-x](9|3)[^\]]*.mp4)/gi)
  {
    $formats{$2} = { video => $video, playpath => $1, ratio => "$4x$5" };
  }

# alternative formats when download available immediately after shows
  while ($video =~ m/(mp4:[^\]]+-([0-9]{3,4})kbps.mp4)/gi)
  {
    $formats{$2} = { video => $video, playpath => $1, ratio => "16x9" };
  }
  while ($video =~ m/(mp4:[^\]]+-([0-9]{3,4})kbps.\d+.mp4)/gi)
  {
    $formats{$2} = { video => $video, playpath => $1, ratio => "16x9" };
  }

  my @rates = sort { $a <=> $b } keys(%formats);
  my $cnt = $#rates;

  die "Unable to find video in XML" unless $cnt >= 0;

  my $q = $prefs->{quality};
  if ( $q =~ /^\s*\d+\s*$/) {
     my $rate = $rates[0];
     foreach (@rates) {
        if ( $q >= $_ )
        { $rate = $_;}
     }
     $q = $rate;
  }
  else {
    my $num = {high =>int($cnt), medium => int(($cnt+1)/2), low => 0}->{$q};
    if (! defined $num ) { 
      $num = int($cnt);
    }
    $q = $rates[$num];
  }
  
  my $format = $formats{$q};
  if ( ! defined($format)) {
    $format = $formats{$rates[int($cnt)]};
  }

  $video = $format->{"video"};
  my $rtmp = decode_entities($video =~ /base="(rtmp[^"]+)/);
  my($playpath) = $format->{"playpath"};
  my($flv) = $playpath =~ m{/([^/]+)$};
  $flv =~ s/\.mp4$/.flv/;
  if ( $flv =~ /_PC01\d+_/i ) {
    $flv =~ s/_/_${progtitle}-${eptitle}_/;
    $flv = title_to_filename($flv);
  } 

  # Get subtitles if necessary.
  if ($prefs->{subtitles}) {
    info "Subtitle Fetching";
    if ($video =~ m%<URL><!\[CDATA\[(http://subtitles\.[^\]]*)\]\]></URL>%) {
      my $subtitles_url  = $1;
      info "Subtitle URL $subtitles_url";
      $browser->get($subtitles_url);

      if (!$browser->success) {
        info "Couldn't download Itv subtitles: " . $browser->response->status_line;
      }
#      Code to save .ttml file
#      my $subtitles_ttml = $flv;
#      my $subtext = $browser->content;
#      my $istart = index $subtext, "<";
#      $subtext = substr($subtext, $istart) unless ($istart < 0);
#      $subtext =~ s/UTF-16/utf8/;

#      $subtitles_ttml =~ s/\.flv$/\.ttml/;
      
#      unlink($subtitles_ttml);
#      open my $fh, ">", $subtitles_ttml;
#      binmode $fh;
#      print $fh $subtext;
#      close $fh;

      my $subtitles_file = $flv;
      $subtitles_file =~ s/\.flv$/\.srt/;

      convert_ttml_subtitles_to_srt($browser->content, $subtitles_file);

      info "Saved subtitles to $subtitles_file";
    }
  }

  my $dlparams = {
    rtmp => $rtmp,
    playpath => $playpath,
    flv => $flv,
    itv_swfhash($browser, "http://www.itv.com/mercury/Mercury_VideoPlayer.swf")
  };
  
  if ($dlparams->{swfsize} < 10) {
    # Use hardcoded value if failed
    print STDERR "Size too small - using hardcoded values for swf\n";
    $dlparams->{swfUrl} = 'http://www.itv.com/mercury/Mercury_VideoPlayer.swf';
    $dlparams->{swfsize} = 990750;
    $dlparams->{swfhash} = 'b6c8966da3f49610be7178b01ca33d046bbf915e2908d9dafe11e4b042d8eeea';
  }
  return $dlparams;
}


use constant FP_KEY => "Genuine Adobe Flash Player 001";

# Replacement swfhash upto version 19
sub itv_swfhash {
  my($browser, $url) = @_;

  $browser->get($url);

  return itv_swfhash_data($browser->content, $url);
}

sub itv_swfhash_data {
  my ($data, $url) = @_;

    die "Must have Digest::SHA for this RTMP download\n"
        unless eval {
          require Digest::SHA;
        };

  # swf file header
  # swf signature type FWS uncompressed, CWS Zlib compression, ZWS LZMA compression
  # swf version
  my ($swftype, $swfversion , $swfsize) = unpack ("a3CI", substr($data, 0, 8));

  print STDERR "swf type = $swftype version = $swfversion size = $swfsize\n";

  if ($swftype eq 'CWS' ) {

    die "Must have Compress::Zlib for this RTMP download\n"
        unless eval {
          require Compress::Zlib;
        };

    # sfw uncompressed header.
    $data = "F" . substr($data, 1, 7)
                . Compress::Zlib::uncompress(substr $data, 8);

  } elsif ($swftype eq 'ZWS') {
    # swf version 13 and later
    print STDERR "Warning Lzma not supported\n";
  } elsif ($swftype ne 'FWS') {
    print STDERR "Warning Not a SWF Format file\n"; 
  }

  my $datalen = length $data;
  if ($datalen != $swfsize) {
    print STDERR "swf size $swfsize doesn't match uncompressed size $datalen\n";
  }

  return
    swfsize => $datalen,
    swfhash => Digest::SHA::hmac_sha256_hex($data, FP_KEY),
    swfUrl  => $url;
}


1;
