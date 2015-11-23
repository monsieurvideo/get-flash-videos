# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Dplay;

use strict;
use FlashVideo::Utils;
use FlashVideo::JSON;
use HTTP::Cookies;
use URI::Escape;

my $bitrate_index = {
  high   => 0,
  medium => 1,
  low    => 2
};

sub find_video {
 my ($self, $browser, $embed_url, $prefs) = @_;
 my $title = extract_title($browser);
 my $video_id = ($browser->content =~ /data-video-id="([0-9]*)"/)[0];
 my $url = "https://secure.dplay.se/secure/api/v2/user/authorization/stream/$video_id?stream_type=hls";

 my $cookies = HTTP::Cookies->new;
 $cookies->set_cookie(0, 'dsc-geo', uri_escape('{"countryCode": "SE"}'), '/', 'secure.dplay.se'); 
 $browser->cookie_jar($cookies);
 $browser->get($url);

 my $filename = title_to_filename($title, "mp4");

 my $jsonstr  = $browser->content;
 my $json     = from_json($jsonstr);
 my $hls_url  = $json->{hls};

 if ($json->{type} eq "drm") {
   die "Does not support DRM videos";
 }

 return {
   downloader => "hls",
   flv        => $filename,
   args       => { hls_url => $hls_url, prefs => $prefs} 
 }; 

}

1;
