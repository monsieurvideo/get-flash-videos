# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Blip;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;
  my $base = "http://blip.tv";

  my $has_xml_simple = eval { require XML::Simple };
  if(!$has_xml_simple) {
    die "Must have XML::Simple installed to download Blip videos";
  }

  my $id;
  if($embed_url =~ m!/(\d+)!) {
    $id = $1;
  } elsif($embed_url =~ m!/play/!) {
    $browser->get($embed_url);

    if($browser->response->is_redirect
        && $browser->response->header("Location") =~ m!(?:/|%2f)(\d+)!i) {
      $id = $1;
    }
  }
  die "No ID found\n" unless $id;

  $browser->get("$base/rss/flash/$id");

  my $xml = eval {
    XML::Simple::XMLin($browser->content)
  };

  if ($@) {
    die "Couldn't parse Blip XML : $@";
  }

  my $content = $xml->{channel}->{item}->{"media:group"}->{"media:content"};

  my $url = ref $content eq 'ARRAY' ? $content->[0]->{url} : $content->{url};
  my $extension = ($url =~ /\.(\w+)$/)[0];

  my $filename = title_to_filename($xml->{channel}->{item}->{title}, $extension)
    || get_video_filename($extension);

  # I want to follow redirects now.
  $browser->allow_redirects;

  return $url, $filename;
}

1;
