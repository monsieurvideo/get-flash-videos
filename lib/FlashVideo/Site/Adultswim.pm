# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Adultswim;

use strict;
use FlashVideo::Utils;

sub find_video {
	my($self, $browser, $embed_url) = @_;

	my $xml;
	my $id;

	my $segIds;
	if($browser->{content} =~ m/(<meta[^>]* ?name=["']segIds["'] ?[^>]*>)/){
		my $text = $1;
		if($text =~ m/content=["']([^"']+)["']/){
			$segIds = $1;
		}
	}

	($segIds)=$browser->{content} =~ m/<section[^>]* ?data-segment-ids=["'](.+?)["'] ?[^>]*>/ if(!$segIds);
	my ($id1) = $segIds =~ m/^([0-9a-f]+)/;

	my $title;
	if($browser->{content} =~ m/<meta property=["']og:title["'] content=["']([^"']+)["']\/>/){
		$title = $1;
	}

	my $configURL = "/tools/swf/player_configs/watch_player.xml";

#	foreach($xml->{head}->{script}){
		if($browser->content =~ /pageObj\.configURL = ["']([^"']+)["'];/) {
			$configURL = $1;
		}
#	}

	$browser->get($configURL);

	my $serviceConfigURL;

	if($browser->response->code =~ /^30\d$/){

		$xml = from_xml($browser);

		if($xml->{serviceConfigURL} ne ""){
			$serviceConfigURL = $1;
		}
	} else {
		$serviceConfigURL = "http://asfix.adultswim.com/staged/AS.configuration.xml";
	}

	$browser->get($serviceConfigURL);

	$xml = from_xml($browser);

	my $getVideoPlayerURL;
	if($xml->{config}->{services}->{getVideoPlaylist}->{url} ne ""){
		$getVideoPlayerURL = $1;
	} else {
		$getVideoPlayerURL = "http://asfix.adultswim.com/asfix-svc/episodeservices/getVideoPlaylist?networkName=AS";
	}

	my $videoURL = "$getVideoPlayerURL&id=$id1";
	$browser->get($videoURL);

	$xml = from_xml($browser);
	my $pick;
	my $bitrate;
	my $file_url;
	foreach(@{$xml->{entry}}){
		if(!($_->{ref}->{href} =~ m/iPhone/)){
			$file_url=$_->{ref}->{href};
			$pick = $1; last;
		}
	}

#	grep { $_->{name} eq "mimeType" } @{$_->{param}})[0]->{value} 
#	my $pick = (grep { $_->{param}->{value}->[3] eq "video/x-flv" } @{$xml->{entry} } )[0];

#	my $pick = $xml->{entry}[4];

#	my $file_url = $pick->{ref}->{href};

	# $prefs->{quality}

	return $file_url, title_to_filename($title);
}

1;
