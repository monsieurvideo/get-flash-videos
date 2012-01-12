# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Escapistmagazine;

use strict;
use FlashVideo::Utils;
use FlashVideo::JSON;

sub find_video {
  my ($self, $browser, $embed_url) = @_;
  # Actual Escapist Part
  my $title;
	my $url;
	if ($browser->content =~ /<div[^>]*class=['"]name['"]>(.*?)<\/div>/) {
		$title = $1;
		$title =~ s/<[^>]*>//g;
	} else {
		$title = extract_title($browser);
	}

	my $config_url;
	# This may be too specific, and thus more fragile than I'd like
	# I didn't want to hit something unrelated, though
	if ($browser->content =~ /<param name=['"]flashvars['"] value=['"]config=([^'"]*)['"]/) {
		$config_url = $1;
	} else {
		die "No Video Info URL Found\n";
	}

	# Without this header the server gives you a 500 response
	# It also then puts you on some sort of list that gives you that response 
	# for even good requests hours if not days
	# This took a long time to figure out.
	$browser->add_header(Accept => '*/*');
	$browser->get("$config_url");
	my $replaced = $browser->content;
	$replaced =~ s/'/"/g;
	my $json = from_json($replaced);

	my $item;
	for $item (@{$json->{playlist}}) {
		if ($item->{eventCategory} eq "Video") {
			$url = $item->{url};
		}
	}
	return $url, title_to_filename($title);
}
