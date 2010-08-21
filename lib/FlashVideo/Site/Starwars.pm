# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Starwars;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my $video_id;
  if ($browser->uri->as_string =~ /view\/([0-9]+)\.html$/) {
    $video_id = $1;
  }

  my $page_url = $browser->uri->as_string;

  $browser->get("http://starwars.com/webapps/video/item/$video_id");
  my $xml = from_xml($browser);

  my $items = $xml->{channel}->{item};
  my $item = ref $items eq 'ARRAY' ?
    (grep { $_->{link}->{content} eq "/video/view/" . $video_id . ".html" } @$items)[0] :
    $items;

  debug $item->{enclosure}->{url};

  my $rtmpurl = $item->{enclosure}->{url};
  $rtmpurl =~ s/^rtmp:/rtmpe:/; # for some reason it only works with rtmpe

  my $title = $item->{title}; # is there a way to unencrypt <CDATA> tags? or does the xml handler do this for us?

  return {
    flv => $title,
    rtmp => title_to_filename($rtmpurl),
    playpath => $item->{content}->{url}
  };
}

1;
