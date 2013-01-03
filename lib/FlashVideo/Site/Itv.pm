# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Itv;

use strict;
use FlashVideo::Utils;
use HTML::Entities;

sub find_video {
  my ($self, $browser, $page_url, $prefs) = @_;

  my($id) = $browser->uri =~ /Filter=(\d+)/;
  my $productionid;
  if ( $id )
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

  }
  else {
    ($productionid) = $browser->content =~ /\"productionId\":\"([^\"]+)\"/i;
    print "Production ID $productionid\n";
    die "No id (filter) found in URL or production id\n" unless $productionid;
    $browser->post("http://mercury.itv.com/PlaylistService.svc",
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

  }
  # We want the RTMP url within a <Video timecode=...> </Video> section.
  debug $browser->content;
  die "Unable to find <Video> in XML" unless $browser->content =~ m{<Video timecode[^>]+>(.*?)</Video>}s;
  my $video = $1;

  # Parse list of availible formats and lookup their resolutions

  my %formats;

# Normal format for catchup service
  while ($video =~ m/(mp4:[^\]]+_[A-Z]+([0-9]{3,4})_(16|4)[-x](9|3)[^\]]*.mp4)/gi)
  {
    $formats{$2} = { video => $video, playpath => $1, ratio => "$3x$4" };
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

  return {
    rtmp => $rtmp,
    playpath => $playpath,
    flv => $flv,
    swfhash($browser, "http://www.itv.com/mercury/Mercury_VideoPlayer.swf")
  };
}

1;
