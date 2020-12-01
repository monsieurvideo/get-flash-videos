# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Ardmediathek;

use strict;
use FlashVideo::Utils;
use FlashVideo::JSON;

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;
  my ($id, $jsonurl, $filename, $videourl, $quality);

  $quality = {high => 3, medium => 2, low => 1}->{$prefs->{quality}};

  if($embed_url =~ /documentId=(\d+)/) {
    $id = $1;
    debug "Ardmediathek::find_video called, embed_url = \"$embed_url\"\n";
    debug "documentId: $id\n";
    debug "quality: $quality\n";
    if($browser->content =~ /<title>.*?&quot;(.*?)&quot;/) {
      $filename = "$1.mp4";
    } else {
      $filename = "$id.mp4";
    }
    $filename = title_to_filename($filename);
    debug "filename: $filename\n";

    $jsonurl = "http://www.ardmediathek.de/play/media/$id?devicetype=pc&features=";
    $browser->get($jsonurl);
    my $result = from_json($browser->content());
    $videourl = $result->{_mediaArray}[1]->{_mediaStreamArray}[$quality]->{_stream};
    debug "found videourl: $videourl\n";

  }
  return $videourl, $filename;
}

1;
