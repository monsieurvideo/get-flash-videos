# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Tv;

use strict;
use FlashVideo::Utils;
use FlashVideo::JSON;

sub find_video {
  my($self, $browser, $embed_url, $prefs) = @_;

  # this is very similar to Cbs.pm... maybe they could be merged

  my $pid;
  if ($browser->content =~ /so.addVariable\("pid", "([^"]*)"\);/) {
    $pid = $1;
  } else {
    die "Could not find PID for video! " . $browser->uri->as_string;
  }

  my $url = "http://release.theplatform.com/content.select?format=SMIL&Tracking=true&balance=true&pid=$pid";
  $browser->get($url);
  if (!$browser->success) {
    die "Couldn't download content.select $url: " . $browser->response->status_line;
  }

  my $xml = from_xml($browser);
  my $items = $xml->{body}->{ref};
  my $item = ref $items eq 'ARRAY' ?
    (grep { $_->{src} =~ /^rtmp:\/\// } @$items)[0] :
    $items;

  my $filename = title_to_filename($item->{title});

  my $playpath = "";
  my $rtmpurl = $item->{src};

  $rtmpurl =~ s/<break>.*//;

  return {
    flv => $filename,
#    playpath => $playpath,
    rtmp => $rtmpurl,
  };
}

sub can_handle {
  my($self, $browser, $url) = @_;
  # Only trigger for tv.com (not all sites in the .tv TLD for example)
  return $browser->uri->host =~ /(^|\.)tv\.com$/;
}

1;
