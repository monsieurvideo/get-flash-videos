# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Todaysbigthing;

use strict;
use FlashVideo::Utils;

my $base = "http://www.todaysbigthing.com/betamax";

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my $has_xml_simple = eval { require XML::Simple };
  if(!$has_xml_simple) {
    die "Must have XML::Simple installed to download Today's big thing videos";
  }

  my $id;
  if($browser->content =~ /item_id=(\d+)/) {
    $id = $1;
  } elsif($embed_url =~ m![/:](\d+)!) {
    $id = $1;
  }
  die "No ID found\n" unless $id;

  $browser->get("$base:$id");

  my $xml = eval {
    XML::Simple::XMLin($browser->content)
  };

  if ($@) {
    die "Couldn't parse Today's big thing XML: $@";
  }

  my $title = $xml->{title};
  $title = ($browser->content =~ /<title>(.*?)[|<]/)[0] if ref $title;
  my $filename = title_to_filename($title) || get_video_filename();

  my $url = $xml->{flv};
  die "No FLV location" unless $url;

  return $url, $filename;
}

sub can_handle {
  my($self, $browser, $url) = @_;

  return $browser->content =~ $base;
}

1;
