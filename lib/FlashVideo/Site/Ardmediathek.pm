# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Ardmediathek;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;
  my ($id, $filename, $videourl, $quality);

  $quality = {high => '2', low => '1'}->{$prefs->{quality}};

  if($embed_url =~ /documentId=(\d+)/) {
    $id = $1;
    debug "Ardmediathek::find_video called, embed_url = \"$embed_url\"\n";
    debug "documentId: $id\n";
    debug "quality: $quality\n";

    if($browser->content =~ /addMediaStream\(0, $quality, "(rtmp:\/\/.*?)", "(.*?)"/) {
      $videourl = "$1/$2";
      debug "found videourl: $videourl\n";
      if($2 =~ /clip=(.*?)&/) {
        $filename = "$1.flv";
      } else {
        $filename = "$id.flv";
      }
      $filename = title_to_filename($filename);

      $videourl = {
        rtmp => $videourl,
        swfVfy => "http://www.ardmediathek.de/ard/static/player/base/flash/PluginFlash.swf"
      };
    }
  }
  return $videourl, $filename;
}

1;
