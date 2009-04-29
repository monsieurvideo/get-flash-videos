# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Spike;

use strict;
use FlashVideo::Utils;
use URI::Escape;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my $has_xml_simple = eval { require XML::Simple };
  if(!$has_xml_simple) {
    die "Must have XML::Simple installed to download Spike videos";
  }

  my $config_url;
  if($browser->content =~ /config_url\s*=\s*["']([^"']+)/) {
    $config_url = $1;
  } elsif($browser->content =~ /(?:ifilmId|flvbaseclip)=(\d+)/) {
    $config_url = "/ui/xml/mediaplayer/config.groovy?ifilmId=$1";
  }
  die "No config_url/id found\n" unless $config_url;

  $browser->get(uri_unescape($config_url));
  my $xml = XML::Simple::XMLin($browser->content);

  my $feed = uri_unescape($xml->{player}->{feed});
  die "Unable to find feed URL\n" unless $feed;

  $browser->get($feed);
  $xml = XML::Simple::XMLin($browser->content);

  my $filename = title_to_filename($xml->{channel}->{title})
    || get_video_filename();

  my $mediagen_url = $xml->{channel}->{item}->{"media:group"}->{"media:content"}->{url};
  die "Unable to find mediagen URL\n" unless $mediagen_url;

  $browser->get($mediagen_url);
  $xml = XML::Simple::XMLin($browser->content);

  my $rendition = $xml->{video}->{item}->{rendition};
  $rendition = [ $rendition ] unless ref $rendition eq 'ARRAY';

  my $url = (sort { $b->{bitrate} <=> $a->{bitrate} } @$rendition)[0]->{src};

  if($url =~ /^rtmp:/) {
    return {
      flv => $filename,
      rtmp => $url
    };
  }

  # I want to follow redirects now.
  $browser->allow_redirects;

  return $url, $filename;
}

1;
