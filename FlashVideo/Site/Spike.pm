# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Spike;

use strict;
use base 'FlashVideo::Site::Mtvnservices';

use FlashVideo::Utils;
use URI::Escape;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my $has_xml_simple = eval { require XML::Simple };
  if(!$has_xml_simple) {
    die "Must have XML::Simple installed to download Spike videos";
  }

  my $page_url = $browser->uri->as_string;

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

  return $self->handle_feed($feed, $browser, $page_url);
}

1;
