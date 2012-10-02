# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Presstv;

use strict;
use FlashVideo::Utils;
use URI;

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;

  my $page_url = $browser->uri;
  my $swfVfy = ($browser->content =~ /SWFObject\('(http.[^']+)'/i)[0];
  my $rtmp = ($browser->content =~ /'streamer',\s*'(rtmp:[^']+)'/i)[0];
  my $file = ($browser->content =~ /'file',\s*'([^']+)'/i)[0];
  my $app = ($rtmp =~ m%rtmp://[^/]+/(.*)$%)[0];
  my $filename = ($file =~ m%/([^/]+)$%)[0];
  $filename =~ s/:/_/g;

  my @rtmpdump_commands;

  my $args = {
    app => $app,
    pageUrl => $page_url,
    swfVfy => $swfVfy,
    rtmp => $rtmp,
    playpath => $file,
    flv => "$filename.flv",
  };

  push @rtmpdump_commands, $args;

  if (@rtmpdump_commands > 1) {
    return \@rtmpdump_commands;
  }
  else {
    return $rtmpdump_commands[-1];
  }
}

sub can_handle {
  my($self, $browser, $url) = @_;

  my $host = URI->new($url)->host;
  return 1 if $url && $host =~ /^presstv\.(com|ir)$/;
  return 1 if $url && $host =~ /\.presstv\.(com|ir)$/;
  debug "Presstv.pm no match found\n";
  return 0;
}

1;
