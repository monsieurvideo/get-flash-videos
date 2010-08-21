# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Flickr;

use strict;
use FlashVideo::Utils;
use URI::Escape;

my $get_mtl = "http://www.flickr.com/apps/video/video_mtl_xml.gne?v=x";

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my($id) = $browser->content =~ /photo_id=(\d+)/;
  my($secret) = $browser->content =~ /photo_secret=(\w+)/;

  die "No video ID found\n" unless $id;

  $browser->get($get_mtl . "&photo_id=$id&secret=$secret&olang=en-us&noBuffer=null&bitrate=700&target=_self");

  my $xml = from_xml($browser);

  my $guid = $self->make_guid;
  my $video_id = $xml->{Data}->{Item}->{id}->{content};
  my $playlist_url = $xml->{Playlist}->{TimelineTemplates}->{Timeline}
    ->{Metadata}->{Item}->{playlistUrl}->{content};

  die "No video ID or playlist found" unless $video_id and $playlist_url;

  $browser->get($playlist_url
    . "?node_id=$video_id&secret=$secret&tech=flash&mode=playlist"
    . "&lq=$guid&bitrate=700&rd=video.yahoo.com&noad=1");

  $xml = eval { XML::Simple::XMLin($browser->content) };
  die "Failed parsing XML: $@" if $@;

  $xml = $xml->{"SEQUENCE-ITEM"};
  die "XML not as expected" unless $xml;

  my $filename = title_to_filename($xml->{META}->{TITLE});
  my $url = $xml->{STREAM}->{APP} . $xml->{STREAM}->{FULLPATH};

  return $url, $filename;
}

sub make_guid {
  my($self) = @_;

  my @chars = ('A' .. 'Z', 'a' .. 'z', 0 .. 9, '.', '_');
  return join "", map { $chars[rand @chars] } 1 .. 22;
}

1;
