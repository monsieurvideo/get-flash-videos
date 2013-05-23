# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Movieclips;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my $video_id = ($browser->content =~ /<meta name="video_id" content="([^"]+)"/i)[0];

  debug "video_id = " . $video_id;

  $browser->get("http://config.movieclips.com/player/config/embed/$video_id/?loc=US");

  my $xml = from_xml($browser->content);

  my $playpath = $xml->{video}->{properties}->{file_path};

  my $title = $xml->{video}->{properties}->{clip_title};

  debug $playpath;
  debug title_to_filename($title);

  return {
    flv => title_to_filename($title, 'flv'),
    swfUrl => "http://static.movieclips.com/embedplayer.swf?shortid=$video_id",
    app => "ondemand",
    rtmp => "rtmp://media.movieclips.com",
    playpath => $playpath
  };
}

1;
