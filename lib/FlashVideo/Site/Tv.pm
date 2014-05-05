# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Tv;

use strict;
use FlashVideo::Utils;
use FlashVideo::JSON;

our $VERSION = '0.01';
sub Version() { $VERSION; }

sub find_video {
  my($self, $browser, $embed_url, $prefs) = @_;

  my $pid;
  # TV.com and CBS now use MPX video source.
  if ($browser->content =~ /(so.addVariable\("pid",|(?:flashvars|video.settings).pid =) ["']([^"']*)["']\)?;/) {
    $pid = $2;
  } else {
    die "Could not find PID for video! " . $browser->uri->as_string;
  }

  # URL comes from http://canstatic.cbs.com/chromeless/uvp/tvcom/tvcom.xml
  # (CBS: http://canstatic.cbs.com/chromeless/uvp/cbs/cbs.xml)
  print "Video PID is $pid\n";
  my $url = "http://link.theplatform.com/s/dJ5BDC/$pid?format=SMIL&Tracking=true&mbr=true";
  # Old non-MPX URL
  #my $url = "http://release.theplatform.com/content.select?format=SMIL&Tracking=true&balance=true&pid=$pid";
  $browser->get($url);
  if (!$browser->success) {
    die "Couldn't download content.select $url: " . $browser->response->status_line;
  }

  my $xml = from_xml($browser);
  # Get base URL
  my $items = $xml->{head}->{meta};
  $items = (grep { $_->{base} } @$items)[0] if ref $items eq 'ARRAY';
  my $base = $items->{base} ? $items->{base} : '';

  # Find video URLS, as well as video URLS inside <switch> clauses.
  # Sometimes they are <video> tags instead of <ref> tags.
  my @items = ();
  my $items = $xml->{body}->{switch};
  foreach ( $xml->{body}, ref $items eq 'ARRAY' ? @$items : $items ) {
    foreach my $kw ('ref','video') {
      my $subitems = $_->{$kw};
      push @items, ref $subitems eq 'ARRAY' ? @$subitems : $subitems;
    }
  }
  my $item = (grep { $_ && ( $_->{src} =~ /^rtmpe?:\/\// ||
                             $_->{src} !~ /:\/\// ) } @items)[0];

  my $filename = title_to_filename($item->{title});
  $item->{src} =~ /\.([a-zA-Z0-9]+)($|\?)/;
  my $playpath = "$1:$item->{src}"; # mp4:video/[...]/[...].mp4

  return {
    flv => $filename,
    playpath => $playpath,
    rtmp => $base,
    swfUrl => 'http://vidtech.cbsinteractive.com/player/3_1_0/CBSI_PLAYER.swf',
    #swfUrl => 'http://canstatic.cbs.com/[[IMPORT]]/vidtech.cbsinteractive.com/player/3_2_2/CBSI_PLAYER_HD.swf', # Newer, 2013-12-16
    pageUrl => $embed_url,
  };
}

sub can_handle {
  my($self, $browser, $url) = @_;
  # Only trigger for tv.com (not all sites in the .tv TLD for example)
  # Also supports CBS.com
  return $url && URI->new($url)->host =~ /(^|\.)(tv|cbs)\.com$/;
}

1;
