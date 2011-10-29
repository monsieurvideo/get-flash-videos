# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Itv;

use strict;
use FlashVideo::Utils;
use HTML::Entities;

my $resolutions = {
  "16x9" => {
    "400" => [412, 232],
    "600" => [512, 288],
    "800" => [640, 360],
    "1200" => [704, 396],
  },
  "4x3" => {
    "400" => [320, 240],
    "600" => [384, 288],
    "800" => [480, 360],
    "1200" => [528, 396],
  },
};

sub find_video {
  my ($self, $browser, $page_url, $prefs) = @_;

  my($id) = $browser->uri =~ /Filter=(\d+)/;
  die "No id (filter) found in URL\n" unless $id;

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

  # We want the RTMP url within a <Video timecode=...> </Video> section.
  debug $browser->content;
  die "Unable to find <Video> in XML" unless $browser->content =~ m{<Video timecode[^>]+>(.*?)</Video>}s;
  my $video = $1;

  # Parse list of availible formats and lookup their resolutions
  my(@formats);
  while ($video =~ m/(mp4:[^\]]+([0-9]{3})_(16[-x]9|4[-x]3).mp4)/gi)
  {
    push @formats, { playpath => $1, resolution => $resolutions->{$3}->{$2}};
  }

  my $format = $prefs->quality->choose(@formats);

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
