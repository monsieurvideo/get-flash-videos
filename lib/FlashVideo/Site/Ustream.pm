# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Ustream;

use strict;
use FlashVideo::Utils;
use MIME::Base64;

our $VERSION = '0.01';
sub Version() { $VERSION };

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  unless(eval { require Data::AMF::Packet }) {
    die "Must have Data::AMF::Packet installed to download ustream videos";
  }

  my $packet = Data::AMF::Packet->deserialize(decode_base64(<<EOF));
AAAAAAABAA9WaWV3ZXIuZ2V0VmlkZW8AAi8xAAAAiAoAAAABAwAIYXV0b3BsYXkBAQAEcnBpbgIA
GHJwaW4uMC4xODM2MDk4NTkzMTY0Njg5OAAHdmlkZW9JZAIABzIzNTU3MzYAB3BhZ2VVcmwCACZo
dHRwOi8vd3d3LnVzdHJlYW0udHYvcmVjb3JkZWQvMjM1NTczNgAHYnJhbmRJZAIAATEAAAkK
EOF

  my $title = extract_info($browser)->{meta_title};

  # http://www.ustream.tv/recorded/\d+
  my($video_id) = $browser->uri =~ m{recorded/(\d+)};
  $video_id ||= $browser->content =~ m{vid\s*=\s*["']?(\d+)};

  $packet->messages->[0]->{value}->[0]->{videoId} = $video_id;

  my $data = $packet->serialize;

  $browser->post(
    # This is hidden as gwUrl inside the second loaded SWF
    # (viewer.rsl.VER.swf), too much effort to extract properly.
    "http://rgw.ustream.tv/gateway.php",
    Content_Type => "application/x-amf",
    Content => $data
  );

  die "Failed to post to Ustream AMF gateway"
    unless $browser->response->is_success;

  # Data::AMF fails to understand this response, so just parse ourselves.
  my($flv_url) = $browser->content =~ /flv.{3,5}(http:[^\0]+)/;

  $browser->allow_redirects;

  return $flv_url, title_to_filename($title);
}

1;
