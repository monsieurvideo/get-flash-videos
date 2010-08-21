# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Truveo;

use strict;
use FlashVideo::Utils;

sub find_video {
  my($self, $browser, $embed_url, $prefs) = @_;

  my($videourl) = $browser->content =~ /var videourl = "(.*?)"/;

  # Maybe we were given a direct URL..
  $videourl = $embed_url
    if !$videourl && $browser->uri->host eq 'xml.truveo.com';

  die "videourl not found" unless $videourl;

  $browser->get($videourl);

  if($browser->content =~ /url=(http:.*?)["']/) {
    my $redirect = url_exists($browser, $1);

    $browser->get($redirect);

    my($package, $possible_url) = FlashVideo::URLFinder::find_package($redirect, $browser);

    die "Recursion detected" if $package eq __PACKAGE__;

    return $package->find_video($browser, $possible_url, $prefs);
  } else {
    die "Redirect URL not found";
  }
}

1;
