# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Spiegel;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;
  my ($video_id, $xmlurl, $filename, $videourl, $quality);

  debug "Spiegel::find_video called, embed_url = \"$embed_url\"\n";
  
  $quality = {
      high => '.mp4',
      medium => 'VP6_928.flv',
      low => 'VP6_576.flv'}->{$prefs->{quality}};

  if($embed_url =~ /.*?www.spiegel.de\/video\/video-(\d*).html/) {
    $video_id = $1;
    $xmlurl = "http://video.spiegel.de/flash/$video_id.xml";
  } else {
    die "Only works for http://www.spiegel/de/video/video... urls\n";
  }

  if($browser->content =~ /<title>(.*?) -Video/) {
    $filename = "Spiegel_$1_${video_id}_$quality";
    $filename = title_to_filename($filename, $quality);
    $filename =~ s/__/_/g;
  } else {
    die "Unable to find <title> on page $embed_url\n";
  }

  $browser->get($xmlurl);

  if($browser->content =~ /<filename>(.*?$quality)<\/filename>/) {
    $videourl = "http://video.spiegel.de/flash/$1";
  } else {
    die "could not find video url\n";
  }

  return $videourl, $filename;
}

1;
