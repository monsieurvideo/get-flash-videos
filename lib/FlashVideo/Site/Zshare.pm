# A get-flash-videos module for the zshare.net website
# Copyright (C) 2011 Rudolf Olah <rolah@goaugust.com>
# Licensed under the GNU GPL v3 or later

# Created using the instructions from: http://code.google.com/p/get-flash-videos/wiki/AddingSite

package FlashVideo::Site::Zshare;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;
  # $browser is a WWW::Mechanize object
  # $embed_url will normally be the same as the page, but in the case
  # of embedded content it may differ.
  $embed_url = ($browser->content =~ /iframe src="(.*videoplayer.*?)"/i)[0];
  $browser->get($embed_url);
  my $url = ($browser->content =~ /file:.*"(.*?)"/i)[0];
  my $filename = ($browser->content =~ /<title>.*?- (.*)<\/title>/i)[0];
  return $url, $filename;
}

1;
