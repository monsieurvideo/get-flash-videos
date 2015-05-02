# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Daserste;

use strict;
use FlashVideo::Utils;
use Data::Dumper;


sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;
  my ($data_url, $xml, $filename, $videourl, $quality);

  $quality = {
      high => "1.69 Web L VOD adative streaming",
      medium => "1.63 Web M VOD adaptive streaming",
      low => "1.65 Web S VOD adaptive streaming"
  }->{$prefs->{quality}};

  if ($browser->content =~ /dataURL:'(.+?)'/) {
    $data_url = "http://www.daserste.de$1";
    debug "Daserste::find_video data_url = \"$data_url\"\n";
    $xml = from_xml($browser->get($data_url));
    debug "Daserste::find_video Title: ". $xml->{video}->{title};
    debug "Daserste::find_video Quality: " . $quality;
    foreach my $asset (@{$xml->{video}->{assets}->{asset}}) {
        if ($asset->{type} == $quality) {
            $videourl = $asset->{fileName};
            debug "Daserste::find_video Videourl: $videourl";
            $filename = $xml->{video}->{title} . ".mp4";
            $filename = title_to_filename($filename);
            debug "Daserste::find_video Filename: $filename";
        }
    }
  }
  return $videourl, $filename;
}

1;
