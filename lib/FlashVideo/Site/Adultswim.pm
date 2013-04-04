# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Adultswim;

use strict;
use FlashVideo::Utils;

our $VERSION = '0.02';
sub Version() { $VERSION; }

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
	my $bitrate=-1;
	my $file_url;
	foreach(@{$xml->{entry}}){
		next if(ref($_) ne 'HASH');
		next if ($_->{ref}->{href} =~ m,\.akamaihd\.net\/,); 
		next if ($_->{param}->{bitrate} < $bitrate && $_->{ref}->{href} =~ m/iPhone/);
		$file_url=$_->{ref}->{href};
		$bitrate=$_->{param}->{bitrate};
		#print STDERR $_->{param}->{bitrate}."\t".$_->{ref}->{href}."\n";
	}

	return $file_url, title_to_filename($title);
}

1;
