# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Ehow;

use strict;
use FlashVideo::Utils;
use URI::Escape;

sub find_video {
  my ($self, $browser) = @_;

  # Get the video ID
  my $uri;
  if ($browser->content =~ /source=(.*?)[ &]/) {
    $uri = $1;
  }
  else {
    die "Couldn't extract video location from page";
  }

  my $title;
  if ($browser->content =~ /<h1[^>]* class="[^"]*articleTitle[^"]*"[^>]*>(.*?)<\/h1>/x) {
    $title = $1;
  }

  if($uri =~ /^http:/) {
    return $uri, title_to_filename($title);
  }
	elsif($uri =~ /http:%3A/) {
		# This is the embed, and it's the same but encoded.
		$uri = uri_unescape($1);
		# Title is also probably wrong
		if ($browser->content =~ /<a[^>]*>(.*?)<\/a>/) {
			$title = $1;
		}
		return $uri, title_to_filename($title);
	}
	else {
		die "Couldn't extract Flash video URL from embed page";
	}
}


1;
