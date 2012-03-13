# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Zdf;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;
  my ($id, $filename, $videourl, $quality);

  $quality = {high => 'veryhigh', low => 'low'}->{$prefs->{quality}};

  debug "Zdf::find_video called, embed_url = \"$embed_url\"\n";

  if($browser->content =~ /\/video\/(\d*)\/(.*)"/) {
    $id = $1;
    debug "found video $1 $2\n";
    $filename = title_to_filename($2);

    $browser->get("http://www.zdf.de/ZDFmediathek/xmlservice/web/beitragsDetails?id=$id&ak=web");

    if($browser->content =~ /(http:\/\/fstreaming\.zdf\.de\/zdf\/$quality\/.*\.meta)/) {
        $browser->get($1);
        if($browser->content =~ /(rtmp.*)</) {
            debug "found rtmp url\"$1\"\n";
            $videourl = {
                rtmp => $1,
                flv => $filename,
                swfVfy => "http://www.zdf.de/ZDFmediatek/flash/player.swf"
            };
        }
    }
  }
  return $videourl, $filename;
}

1;
