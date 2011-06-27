#################################
#	GlobalTV Canada
#
#	first alpha plugin version
#
#	Input URL should be 
#		http://www.globaltv.com/$show/video/full+episodes/$clip/video.html?v=$contentID
#	where
#		$show		show name
#		$clip		section
#		$contentID 	numeric ID
#	Stavr00
#
#	TODO:	fetch all clips for a show
#

package FlashVideo::Site::Globaltv;

use strict;
use FlashVideo::Utils;
use strict 'refs';

sub find_video {
	my ($self, $browser, $embed_url, $prefs) = @_;

	my $pid;
	if ( $browser->content =~ /pid:\s+"([^"]+?)"/ ) {
		$pid = $1;	
	}
	
	debug "PID = " . $pid;
	
	die "PID not found." unless $pid;
	
	$browser->get("http://release.theplatform.com/content.select?pid=$pid&mbr=true&Embedded=True&Portal=GlobalTV&Site=global_prg.com&TrackBrowser=True&Tracking=True&TrackLocation=True&format=SMIL");

	my $xml = from_xml($browser->content); 

	#
	#	Traverse SMIL XML
	#
	my $maxres = $prefs->quality->quality_to_resolution($prefs->{quality});
	my $sw;		
	my $vid;
	my $title;
	my $url;
	my $rate = 0;
	my $res;
	debug "Enumerating all streams ...";
	foreach $sw (@{ $xml->{body}->{switch} }) {
		if ($sw->{ref}->{src} =~  /^rtmp\:\/\// ) {
			$title = $sw->{ref}->{title};	
			debug "TITLE = " . $title; # short title, not very useful
		}
		if ( ref($sw->{video}) eq ARRAY ) {
			foreach $vid (@{ $sw->{video} }) {
				my $t = $vid->{src};
				if ( $t =~ /^rtmp\:\/\// ) {
					my $w  = $vid->{width};
					my $h  = $vid->{height};
					my $br = $vid->{'system-bitrate'};
					debug ' '. $t ." ". $w . 'x' . $h ."/". $br;
					# don't look at width # ( $w <= @$maxres[0] )
					if ( ( $br > $rate ) && ( $h <= @$maxres[1] ) )	{
						$rate = $br;
						$url = $t;
						$res = $w .'x'. $h .' '. int($br/1024) . 'kb/s';
					}
				}
			}
		}
	}
	
	info 'Stream selected: ' .  $url . ' ' . $res;

	
	# extract filename from URL
	$url =~ /([^\/]+\.mp4$)/;
	$title = $1;
	
	# pass it over to rtmpdump
	return	{
	rtmp => $url,
	    flv => title_to_filename($title)
	};

	
}
	
1;	

