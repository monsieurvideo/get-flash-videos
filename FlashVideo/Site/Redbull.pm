# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Redbull;

use strict;
use FlashVideo::Utils;
use URI;
use HTML::Entities;

sub find_video {
  my ($self, $browser, $page_url) = @_;

  my $video_info_url;
  my $host = $browser->uri->host; 

  if ( ($browser->content =~ /data_url:\s+'([^']+)'/) or
       ($browser->content =~ m{displayVideoPlayer\('([^']+)'\)})) {
    $video_info_url = $1;

    $video_info_url = "http://$host$video_info_url";
  }

  if (!$video_info_url) {
    die "Couldn't find video info URL";
  }

  $browser->get($video_info_url);

  if ($browser->response->is_redirect) {
    $browser->get($browser->response->header('Location'));
  }

  if (!$browser->success) {
    die "Couldn't download Red Bull video info XML: " .
      $browser->response->status_line;
  }
  
  # Red Bull's XML is screwed up:
  #   <?xml version=&amp;&quot;1.0&amp;&quot;
  # All your double encoded entities is belong to them.
  # If Red Bull want to thank us for pointing this out, please send a few cases
  # to Zak and Monsieur.
  my $xml = $browser->content;
  $xml =~ s/&amp;//g;
  $xml = decode_entities($xml);

  my $video_info = from_xml($xml);

  my $file_type = "flv";
  
  if ($video_info->{high_video_url} =~ /\.mp4$/) {
    $file_type = "mp4";
  }

  return {
    flv  => title_to_filename($video_info->{title}, $file_type),
    rtmp => $video_info->{high_video_url}, 
  };
}

1;
