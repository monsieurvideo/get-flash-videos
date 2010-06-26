# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Tbs;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my $oid;
  # as in http://www.tbs.com/video/index.jsp?oid=187350
  if ($browser->uri->as_string =~ /oid=([0-9]*)/) {
    $oid = $1;
  }

  $browser->get("http://www.tbs.com/video/cvp/videoData.jsp?oid=$oid");

  my $xml = from_xml($browser);

  my $headline = $xml->{headline};

  my $akamai;
  if ($xml->{akamai}->{src} =~ /[^,]*,([^,]*)/){
    $akamai = $1;
  }

  my $files = $xml->{files}->{file};
  my $file = ref $files eq 'ARRAY' ?
    (grep { $_->{type} eq "standard" } @$files)[0] :
    $files;

  if($akamai) {
    my $rtmpurl = $akamai . $file->{content};
    die "Unable to find RTMP URL\n" unless $rtmpurl;

    return {
      flv => title_to_filename($headline),
      rtmp => $rtmpurl
    };
  } else {
    # HTTP download
    return $file->{content}, title_to_filename($headline);
  }
}

1;
