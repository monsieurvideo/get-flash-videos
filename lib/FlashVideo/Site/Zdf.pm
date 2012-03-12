# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Zdf;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;
  my ($id, $filename, $videourl, $quality);

  debug "Zdf::find_video called, embed_url = \"$embed_url\"\n";

  my $pageurl = $browser->uri() . "";

  if($browser->content =~ /\/video\/(\d*)\/(.*)"/) {
    $id = $1;
    debug "Found video $1 $2\n";
    $filename = title_to_filename($2);
    debug "found video \"$id\"\n";
    $browser->get("http://www.zdf.de/ZDFmediathek/xmlservice/web/beitragsDetails?id=$id&ak=web");
    #qualies veryhigh high low
    $quality = {high => 'veryhigh', low => 'low'}->{$prefs->{quality}};
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
