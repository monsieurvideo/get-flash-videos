# Part of get-flash-videos. See get_flash_videos for copyright.
# Except the CCR bits, thanks to Fogerty for those.
package FlashVideo::Site::Nfb;

# According to Ohloh code without comments is bad, so as Zakflashvideo is
# currently playing on Guitar Hero..

# There's a place up ahead and I'm goin' just as fast as my feet can fly
use strict;
use FlashVideo::Utils;
use MIME::Base64;

# Come away, come away if you're goin'
sub find_video {
  my ($self, $browser) = @_;
  # leave the sinkin' ship behind.

  my($mid) = $browser->content =~ /mID=(\w+)/;

  # Come on the risin' wind, we're goin' up around the bend.
  if (!eval { require Data::AMF::Packet; }) {
    die "Must have Data::AMF installed to download NFB videos";
  }

  my $packet = decode_base64(<<EOF);
AAAAAAADABFnZXRfbW92aWVfcGFja2FnZQACLzEAAAAiCgAAAAMCAAVBREFBUwIACElET0JKMjYw
AgAHZGVmYXVsdAAJc2V0X3N0YXRzAAIvMgAAAEkKAAAAAwIAC3Rlc3RfZmxpZ2h0AgAISURPQkoy
NjACAChpbmZvczogZmxhc2hQbGF5ZXJWZXJzaW9uPUxOWCAxMCwwLDMyLDE4AAlzZXRfc3RhdHMA
Ai8zAAAASQoAAAADAgALdGVzdF9mbGlnaHQCAAhJRE9CSjI2MAIAKGluZm9zIDpzY3JlZW5SZXNv
bHV0aW9uPTEwMjQsNzY4LCBkcGk9OTY=
EOF

  # Now MonsieurVideo is playing Guitar Hero
  # Bring a song and a smile for the banjo
  my $data = Data::AMF::Packet->new->deserialize($packet);
   
  $data->messages->[0]->{value}->[1] = $data->messages->[1]->{value}->[1] = $mid;

  $data = $data->serialize;

  # Better get while the gettin's good
  $browser->post(
    "http://www.nfb.ca/gwplayer/",
    Content_Type => "application/x-amf",
    Content => $data,
  );

  if (!$browser->success) {
    die "Posting AMF to NFB failed: " . $browser->response->status_line();
  }

  $data = $browser->content;

  # Data::AMF can't deserialize this, and helpfully dies with a Moose-related error
  # message, so just hackily look for RTMP URLs in it directly. MOOOOOSE!
 
  my($title) = $data =~ m'title.{3}([^\0]+)';

  # The video might be available in different qualities. Try to download the 
  # highest quality by default. Qualities in descending order: M1M, M415K, M48K.

  my @rtmp_urls = sort { _get_quality_from_url($b) <=> _get_quality_from_url($a) }
                  ($data =~ m'(rtmp://.*?)\0'g);

  if (!@rtmp_urls) {
    die "Didn't find any rtmp URLs in the packet, our hacky 'parsing' " .
        "code has probably broken";
  }

  # Hitch a ride to the end of the highway where the neons turn to wood.
  my $rtmp_url = $rtmp_urls[0];
  my($host, $app, $playpath) = $rtmp_url =~ m'rtmp://([^/]+)/(\w+)(/[^?]+)';

  if($host eq 'flash.onf.ca') {
    # Special case, clips served from here need two parts of the path for the app.
    $playpath =~ s{^(/[^/]+)/}{};
    $app .= $1;
    # And no file extension
    $playpath =~ s{\.\w+$}{};
  } else {
    # Anything else needs mp4: prefixed
    $playpath = "mp4:$playpath";
  }

  # Oooh!
  return {
    flv => title_to_filename($title),
    rtmp => $rtmp_url,
    app => $app,
    playpath => $playpath
  };
}

sub _get_quality_from_url {
  my($url) = @_;

  if ($url =~ m'/streams/[A-Z](\d+)([A-Z])') {
    my ($size, $units) = ($1, $2);

    $size *= 1024 if $units eq 'M';

    return $size;
  }
}

1;
