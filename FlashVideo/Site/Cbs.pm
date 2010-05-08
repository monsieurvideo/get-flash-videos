# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Cbs;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my $has_xml_simple = eval { require XML::Simple };
  if(!$has_xml_simple) {
    die "Must have XML::Simple installed to download Cbs videos";
  }

  my $pid;
  if ($browser->uri->as_string =~ /pid=([^&]*)/) {
    $pid = $1;
  }

  $browser->get("http://release.theplatform.com/content.select?format=SMIL&Tracking=true&balance=true&MBR=true&pid=$pid");

  debug $browser->content;

  my $xml = XML::Simple::XMLin($browser->content);

  my $items = $xml->{body}->{switch};
  my $item = ref $items eq 'ARRAY' ?
    (grep { $_->{video}->{src} =~ /^rtmp:\/\// } @$items)[0] :
    $items;

  my $rtmpurl = $item->{video}->{src};
  $rtmpurl =~ s/<break>/&lt;break&gt;/; # some reason this break thing is improperly decoded
  my $title = $item->{ref}->{title} . ".flv"; # is there a way to unencrypt <CDATA> tags? or does the xml handler do this for us?

  return {
    rtmp => $rtmpurl,
    flv => $title
  };
}

1;
