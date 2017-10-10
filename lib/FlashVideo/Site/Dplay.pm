# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Dplay;

use strict;
use FlashVideo::Utils;
use FlashVideo::JSON;
use HTTP::Cookies;
use URI::Escape;

our $VERSION = '0.01';
sub Version() { $VERSION;}

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

 if ($prefs->{subtitles})
 {
   my $url_video_data = "http://www.dplay.se/api/v2/ajax/videos?video_id=$video_id";
   $browser->get($url_video_data);
   my $jsonstr = $browser->content;
   my $json = from_json($jsonstr);
   my %subtitles_map = ();
   my %data_map = %{$json->{data}[0]};
   keys %data_map;
   while(my($k, $v) = each %data_map) {
     if ($k =~ m/subtitles_([a-z]+)_srt/ and $v ne '') {
       $subtitles_map{$1} = $v;
     }
   }

   my $num_subs = scalar keys %subtitles_map;
   if ($num_subs == 0) {
     info "No subtitles available";
   }

   while(my($lang, $url) = each %subtitles_map) {
     my $srt_filename = title_to_filename($num_subs > 1 ? "$title-$lang" : "$title", "srt");
     info "Found subtitle language '$lang'";
     $browser->get($url);
     if (!$browser->success) {
       info "Couldn't download subtitles: " . $browser->status_line;
     } else {
       info "Saving subtitles as " . $srt_filename;
       open my $srt_fh, '>', $srt_filename
         or die "Can't open subtitles file $srt_filename: $!";
       binmode $srt_fh, ':utf8';
       print $srt_fh $browser->content;
       close $srt_fh;
     }
   }
 }

 return {
   downloader => "hls",
   flv        => $filename,
   args       => { hls_url => $hls_url, prefs => $prefs} 
 }; 

}

1;
