# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Msnbc;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  # allow 302 redirects
  $browser->allow_redirects;

  # http://today.msnbc.msn.com/id/$cat/vp/$playlist#$id
  # http://today.msnbc.msn.com/id/$cat/vp/#$id
  # http://nbcsports.msnbc.com/id/$cat/vp/$playlist#$id
  # http://nbcsports.msnbc.com/id/$cat/vp/#$id
  # http://www.msnbc.msn.com/id/$cat/$playlist#$id
  # http://www.msnbc.msn.com/id/$cat/#$id
  my $id;
  my $location;
  if ($embed_url =~ /(.+\/id\/)([0-9]+)\/vp\/.+#([0-9]+)/) {
    $location = $1;
    $id = $3;
  } elsif ($embed_url =~ /(.+\/id\/)([0-9]+)\/vp\/([0-9]+)/) {
    $location = $1;
    $id = $3;
  } elsif ($embed_url =~ /(.+\/id\/)([0-9]+)\/.+#([0-9]+)/) {
    $location = $1;
    $id = $3;
  } elsif ($embed_url =~ /(.+\/id\/)([0-9]+)\/#([0-9]+)/) {
    $location = $1;
    $id = $3;
  }
  die "Unable to find location and videoid" unless $location and $id;

  $browser->get($location . $id . '/displaymode/1219/'); # http://today.msnbc.msn.com/id/$id/displaymode/1219/

  my $xml = from_xml($browser->content);

  my $title;
  my $url;
  if ($xml->{video}->{docid} eq $id) {
    $title = $xml->{video}->{title};
    foreach my $media (@{$xml->{video}->{media}}) {
      if ($media->{type} =~ /flashVideo$/i) {
        $url = $media->{content};
        last; #prefer http get over rtmp
      } elsif ($media->{type} =~ /flashVideoStream$/i) {
        $browser->get($media->{content});
        if ($browser->content =~ /<FlashLink>(.+)<\/FlashLink>/i) {
          $url = $1; #rtmp
        }
      }
    }
  }
  die "Unable to extract video url" unless $url;

  if ($url =~ /^rtmp/i) {
    return {
      rtmp => $url,
      flv => title_to_filename($title)
    };
  }

  return $url, title_to_filename($title);
}

1;
