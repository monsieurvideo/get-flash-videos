# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Arte;

use strict;
use FlashVideo::Utils;
use FlashVideo::JSON;

our $VERSION = '0.01';
sub Version { $VERSION; }

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;
  my ($lang, $jsonurl, $filename, $videourl, $quality);

  debug "Arte::find_video called, embed_url = \"$embed_url\"\n";

  my $pageurl = $browser->uri() . "";
  if($pageurl =~ /www\.arte\.tv\/guide\/(..)\//) {
    $lang = $1;
  } else {
    die "Unable to find language in original URL \"$pageurl\"\n";
  }

  if($browser->content =~ /arte_vp_url="(.*)"/) {
    $jsonurl = $1;
    debug "found arte_vp_url \"$jsonurl\"\n";
    ($filename = $jsonurl) =~ s/-.*$//;
    $filename =~ s/^.*\///g;
    $filename .= '_'.$prefs->{quality};
    $filename = title_to_filename(extract_title($browser), 'flv');
  } else {
    die "Unable to find 'arte_vp_url' in page\n";
  }

  $browser->get($jsonurl);

  $quality = {high => 'SQ', medium => 'MQ', low => 'LQ'}->{$prefs->{quality}};

  my $result = from_json($browser->content());

  my $video_json = $result->{videoJsonPlayer}->{VSR}->{'RTMP_'.$quality.'_1'};
   
  $videourl = { 
    rtmp     => $video_json->{streamer},
    playpath => 'mp4:'.$video_json->{url},
    flv      => $filename,
  };

  return $videourl, $filename;
}

1;
