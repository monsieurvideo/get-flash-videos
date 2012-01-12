# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Pennyarcade;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my $id;
	my $title;
	if ($browser->content =~/<h2>(.*?)<\/h2>/) {
		$title = $1;
		$title =~ s/<[^>]*>//g;
	}
	if ($browser->content =~/http:\/\/blip.tv\/play\/(.*).html/) {
		$id = $1;
	} else {
		die "No ID found\n";
	}

	# They actually check this...
	$browser->add_header("User-Agent" => "Android");
	$browser->allow_redirects;
	return "http://blip.tv/play/$id.mp4", title_to_filename($title);
}

1;
