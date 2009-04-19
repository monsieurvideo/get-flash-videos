# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Collegehumor;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;
  my $base = "http://www.collegehumor.com/moogaloop";

  my $has_xml_simple = eval { require XML::Simple };
  if(!$has_xml_simple) {
    die "Must have XML::Simple installed to download Collegehumor videos";
  }

  my $id;
  if($browser->content =~ /clip_id=(\d+)/) {
    $id = $1;
  } elsif($embed_url =~ m![/:](\d+)!) {
    $id = $1;
  }
  die "No ID found\n" unless $id;

  $browser->get("$base/video:$id");

  my $xml = eval {
    XML::Simple::XMLin($browser->content)
  };

  if ($@) {
    die "Couldn't parse Collegehumor XML: $@";
  }

  my $title = $xml->{video}->{caption};
  $title = ($browser->content =~ /<title>(.*?)[|<]/)[0] if ref $title;
  my $filename = title_to_filename($title) || get_video_filename();

  my $url = $xml->{video}->{file};

  return $url, $filename;
}

1;
