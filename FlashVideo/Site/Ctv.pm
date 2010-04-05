# Part of get-flash-videos. See get_flash_videos for copyright.
#
#	Handler module for CTV Canadian broadcaster
#	- Requires RTMPDUMP
#	- Expects an URL in the form of: http://watch.ctv.ca/ $show / $season / $episode /
#	- Each show is split in clips intersected with commercial breaks, so there will be several calls to RTMPDUMP
#	- Streams are restricted to Canadian ISPs
#
#	Stavr0
#
package FlashVideo::Site::Ctv;

use strict;
use FlashVideo::Utils;

sub find_video {
  my($self, $browser, $page_url) = @_;

  # Get the entity ID from the meta tag:  <meta name="EntityId" content="46293" />
  my $entityid = ($browser->content =~ /<meta name="EntityId" content="(\d+)"/i)[0];
  debug "EntityID = " . $entityid;

  die "Couldn't find EntityId in <meta> tags" unless $entityid;

  # Fetch playlist
  $browser->get("http://watch.ctv.ca/AJAX/ClipLookup.aspx?callfunction=Playlist.GetInstance.AddEpisodeClipsAfter&episodeid=$entityid&maxResults=99");
  die "Couldn't download playlist: " . $browser->response->status_line
    if !$browser->success;

  # Parse episode playlist
  my $plist = $browser->content;
  my @found;
  while ($plist =~ /(videoArray\.push[^}]+} \) \);)/gi) {
    push @found, ($1 =~ /Format\:'FLV', ClipId\:'(\d+)'/i);
  }

  # fetch RTMP links
  my @rtmpdump_commands;

  for my $clipid (@found) {
    debug "clipID = $clipid";
    my $rand =  int rand 999999;
    $browser->get("http://esi.ctv.ca/datafeed/flv/urlgenjs.aspx?vid=$clipid&timeZone=-4&random=$rand");

    if ($browser->content =~ /(rtmpe\:\/\/[^\']+)/) {
      my $rtmp = $1;
      my $tcurl = ($rtmp =~ /\?(auth=.+)/ )[0];
      my $filename =  ($rtmp =~ /([^\?\/]+)\?/ )[0];
      $filename =~ s/\.mp4/\.flv/;

      debug "$rtmp, $tcurl, $filename";

      push @rtmpdump_commands, {
        app => "ondemand?$tcurl",
        pageUrl => $page_url,
        swfUrl => "http://watch.ctv.ca/Flash/player.swf?themeURL=http://watch.ctv.ca/themes/CTV/player/theme.aspx",
        tcUrl => "rtmpe://cp45924.edgefcs.net/ondemand?$tcurl",
        auth => ($rtmp =~ /auth=([^&]+)/)[0],
        rtmp => $rtmp,
        playpath => "mp4:" . ($rtmp =~ /ondemand\/(.+)/)[0],
        flv => $filename,
      };
    } elsif($browser->content =~ /geoblock/) {
      die "CTV returned geoblock (content not available in your country)\n";
    }
  }

  return \@rtmpdump_commands;
}

sub can_handle {
  my($self, $browser, $url) = @_;
  return $url =~ m{watch\.ctv\.ca};
}

1;
