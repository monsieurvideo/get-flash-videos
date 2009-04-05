# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::URLFinder;

use strict;
use FlashVideo::Mechanize;
use FlashVideo::Generic;

# The main issue is getting a URL for the actual video, so we handle this
# here - a different package for each site, as well as a generic fallback.
# Each package has a find_video method, which should return a URL, and a
# suggested filename.

sub find_package {
  my($url, $browser) = @_;
  my $package = find_package_url($url);

  if(!defined $package) {
    # Fairly lame heuristic, look for the first URL outside the <object>
    # element (avoids grabbing things like codebase attribute).
    # Also look at embedded scripts for sites which embed their content that way.
 
    URLS: for my $possible_url(
        $browser->content =~ m!(?:<object[^>]+>.*?|<(?:script|embed) [^>]*src=["']?)(http://[^"'> ]+)!gx) {
      $package = find_package_url($possible_url);
      return $package, $possible_url if defined $package;
    }
  }

  if(!defined $package) {
    $package = "FlashVideo::Generic";
  }

  return $package, $url;
}

# Split the URLs into parts and see if we have a package with this name.

sub find_package_url {
  my($url) = @_;
  my $package;

  foreach my $host_part (split /\./, URI->new($url)->host) {
    $host_part = ucfirst lc $host_part;
    $host_part =~ s/[^a-z0-9]//i;

    my $possible_package = "FlashVideo::Site::$host_part";
    eval "require $possible_package";

    if(UNIVERSAL::can($possible_package, "find_video")) {
      $package = $possible_package;
      last;
    }
  }

  return $package;
}

# Utility functions

sub get_browser {
  my $browser = FlashVideo::Mechanize->new(autocheck => 0);
  $browser->agent_alias("Windows Mozilla");

  return $browser;
}

1;
