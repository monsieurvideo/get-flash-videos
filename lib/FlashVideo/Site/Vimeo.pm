# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Vimeo;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;
  my $base = "http://vimeo.com/moogaloop";

  my $id;
  if($embed_url =~ /clip_id=(\d+)/) {
    $id = $1;
  } elsif($embed_url =~ m!/(\d+)!) {
    $id = $1;
  }
  die "No ID found\n" unless $id;

  $browser->get("$base/load/clip:$id/embed?param_fullscreen=1&param_clip_id=$id&param_show_byline=0&param_server=vimeo.com&param_color=cc6600&param_show_portrait=0&param_show_title=1");

  my $xml = from_xml($browser);
  my $filename = title_to_filename($xml->{video}->{caption});
  my $request_signature = $xml->{request_signature};
  my $request_signature_expires = $xml->{request_signature_expires};
  my $isHD = $xml->{video}->{isHD};

  # I want to follow redirects now.
  $browser->allow_redirects;
  
  my $url = "$base/play/clip:$id/$request_signature/$request_signature_expires/?q=hd&type=embed";
  # Check if hd quality is available.
  if ($isHD == '1') { 
      return $url, $filename;
  };
  $url = "$base/play/clip:$id/$request_signature/$request_signature_expires/?q=sd&type=embed";
  return $url, $filename;
}

1;
