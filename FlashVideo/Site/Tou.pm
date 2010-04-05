# Part of get-flash-videos. See get_flash_videos for copyright.
# tou.tv
#
#	Reverse-engineering details at http://store-it.appspot.com/tou/tou.html
#	by Sylvain Fourmanoit
#
#	un grand merci a Sylvain qui a tout debrousaille!
#
#	Stavr0
#
package FlashVideo::Site::Tou;

use strict;
use FlashVideo::Utils;
use URI::Escape;

sub find_video {
  my ($self, $browser) = @_;

  # Get the video ID
  #  on cherche:	,"pid":"45Kr9K8SfwVF1Q5anv7TrRpWa6nMtkG4",
  my $video_id;
  if ($browser->content =~ /,"pid":"(\w+)"/) {
    $video_id = $1;
  }
  debug "Video ID = " . $video_id;

  die "Couldn't find TOU.TV video ID" unless $video_id;

  # on cherche:		,"titleId":"2010-03-29_CA_0052"
  my $filename;
  if ($browser->content =~ /,"titleId":"([^"]+)"/) {
    $filename =  $1 ;
  }
  debug "Filename = " . $filename;

  # On va chercher le XML qui contient le lien RTMP
  #
  $browser->get("http://release.theplatform.com/content.select?pid=$video_id");

  die "Couldn't download TOU.TV XML: " . $browser->response->status_line
    if !$browser->success;

  # on cherche:  	rtmp://medias-flash.tou.tv/ondemand/?auth=daEdwc5 etc...52_hr.mov
  my $url;
  if ($browser->content =~ /(rtmp:[^\<]+)/) {
    $url = uri_unescape($1);
  }
  debug "URL = " . $url;

  # on cherche:		auth=daEdrbRdbbtcYbUb3bQbzacdOaIbNczbva9-blS.uA-cOW-9rqBvkLqxBB
  my $auth;
  if ($url =~ /auth=([^&]+)/ ) {
    $auth = uri_unescape($1);
  }
  debug "AUTH = " . $auth;

  #	on decoupe a partir de 'ondemand/'
  my $app;
  if ($url =~ /(ondemand\/.+)/ ) {
    $app = uri_unescape($1);
  }
  debug "APP = " . $app;

  #  on decoupe apres <break>
  my $playpath;
  if ($url =~ /&lt;break&gt;(.+)/ ) {
    $playpath = uri_unescape($1);
  }
  debug "PLAYPATH = " . $playpath;

=pod
#	et ca donne....
#
#  rtmpdump.exe
#  	--app ondemand/?auth=daEcCamaRcPbCczdabkaRdkbSa8b8aec7bl-blS.4u-cOW-aqpyxlDpFCA&aifp=v0001&slist=002/MOV/HR/2010-03-29_CA_0052_hr;002/MOV/MR/2010-03-29_CA_0052_mr;002/MOV/BR/2010-03-29_CA_0052_br
#  	--flashVer WIN 10,0,22,87
#  	--swfVfy http://static.tou.tv/lib/ThePlatform/4.1.2/swf/flvPlayer.swf
#  	--auth daEcCamaRcPbCczdabkaRdkbSa8b8aec7bl-blS.4u-cOW-aqpyxlDpFCA
#  	--tcUrl rtmp://medias-flash.tou.tv/ondemand/?auth=daEcCamaRcPbCczdabkaRdkbSa8b8aec7bl-blS.4u-cOW-aqpyxlDpFCA&aifp=v0001&slist=002/MOV/HR/2010-03-29_CA_0052_hr;002/MOV/MR/2010-03-29_CA_0052_mr;002/MOV/BR/2010-03-29_CA_0052_br
#  	--rtmp rtmp://medias-flash.tou.tv/ondemand/?auth=daEcCamaRcPbCczdabkaRdkbSa8b8aec7bl-blS.4u-cOW-aqpyxlDpFCA&aifp=v0001&slist=002/MOV/HR/2010-03-29_CA_0052_hr;002/MOV/MR/2010-03-29_CA_0052_mr;002/MOV/BR/2010-03-29_CA_0052_br
#  	--playpath mp4:002/MOV/HR/2010-03-29_CA_0052_hr.mov
#	-o 2010-03-29_CA_0052_hr.flv
=cut

  return {
      app => $app,
      pageUrl => $url,
      swfUrl => "http://static.tou.tv/lib/ThePlatform/4.1.2/swf/flvPlayer.swf",
      tcUrl => $url,
      auth => $auth,
      rtmp => $url,
      playpath => $playpath,
      flv => "$filename.flv",
  };
}

sub search {
  my($self, $search, $type) = @_;

  my $browser = FlashVideo::Mechanize->new;
  $browser->get("http://www.tou.tv/recherche?q=" . uri_escape($search));
  return unless $browser->success;

  my $results = $browser->content;

=pod
  <a href="/les-invincibles" id="MainContent_ctl00_ResultsEmissionsRepeater_TousLesEpisodesLink_0" class="tousEpisodes"></a>
  <a href="/c-est-ca-la-vie" id="MainContent_ctl00_ResultsEmissionsRepeater_TousLesEpisodesLink_1" class="tousEpisodes"></a>
=cut
  my @emissions;
  my @links;

  while($results =~ /<a\s+href="([^"]+)"\s+id="[^"]+"\s+class="([^"]+)/g) {
    debug $1;
    if($2 eq "tousEpisodes") {
      push @emissions, $1;
    }
  }

  for my $emission (@emissions) {
    $browser->get($emission);
    my $liste = $browser->content;

    # <a id="MainContent__ffd5dd30f7cc3406_ctl00_ctl90_DetailsViewTitreEpisodeHyperLink" class="episode" onclick="CTItem(&#39;Episode_titre&#39;,this)" href="/c-est-ca-la-vie/S2009E04"><b>+pisode 4 : Club de boxe pour Úviter le dÚcrochage scolaire&nbsp;</b></a>
    while($liste =~ /<a.+class="episode".+href="([^"]+)".+>(.+)<\/a>/g) {
      push @links, { name => $1, url => "http://www.tou.tv$1", description => $2 };
    }
  }

  return @links;
}

1;
