# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Todaysbigthing;

use strict;
use FlashVideo::Utils;

my $base = "http://www.todaysbigthing.com/betamax";

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my $id;
  if($browser->content =~ /item_id=(\d+)/) {
    $id = $1;
  } elsif($embed_url =~ m![/:](\d+)!) {
    $id = $1;
  }
  die "No ID found\n" unless $id;

  $browser->get("$base:$id");

  my $xml = from_xml($browser);

  my $title = $xml->{title};
  $title = extract_title($browser) if ref $title;
  my $filename = title_to_filename($title);

  my $url = $xml->{flv};
  die "No FLV location" unless $url;

  return $url, $filename;
}

sub can_handle {
  my($self, $browser, $url) = @_;

  return $browser->content =~ $base;
}

1;
