# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Tv3;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  #
  # Decompile of player gives the code:
  #
  # "rtmpe://nzcontent.mediaworks.co.nz:80/" + this.sloc + this.h264 +
  # flv + "_" + this.conSpeed + "K"
  #
  # For TV3, sloc = "tv3".  conSpeed can be 300, 700 or 1500.
  #
  # Looks like h264 is always "/_definst_/mp4:" now.
  #
  # flv is set in JavaScript to "video", with the first "*" removed,
  # and all other "*" translated to "/".
  #
  # var video ="*transfer*09112012*HX044752";
  # video = video.substring(1);
  #
  # rtmpe://nzcontent.mediaworks.co.nz:80/tv3/_definst_/mp4:transfer/09112012/HX044752_700K
  #
  # The SWF URL is: http://static.mediaworks.co.nz/video/6.9/videoPlayer6.9.83.swf?rnd=1932311212
  #
  # ... where the random number appears hard coded in the JavaScript
  # and isn't affected by source IP.
  #
  # So, a reasonable command is:
  #
  # rtmpdump -o file.flv -r rtmpe://nzcontent.mediaworks.co.nz:80/tv3/_definst_/mp4:transfer/09112012/HX044752_700K -s 'http://static.mediaworks.co.nz/video/6.9/videoPlayer6.9.83.swf?rnd=1932311212'
  #

  if ($browser->content !~ m/var\s+video\s*=\"\*([^"]+)\"\s*;/s) {
    die "Unable to extract file";
  }
  my $replace = $1;
  $replace =~ s/\*/\//sg;

  #
  # The player supports 1500, but it isn't clear that any content is
  # available at 1500.
  #
  my $conSpeed = 700;

  my $rtmp = "rtmpe://nzcontent.mediaworks.co.nz:80/tv3/_definst_/mp4:" . $replace . "_" . $conSpeed . "K";

  # Default title is perfect.
  my $filename = title_to_filename(extract_title($browser));
  $filename ||= get_video_filename();

  return {
    rtmp => $rtmp,
    swfVfy => "http://static.mediaworks.co.nz/video/6.9/videoPlayer6.9.83.swf?rnd=1932311212",
    flv => $filename
   };
}

1;
