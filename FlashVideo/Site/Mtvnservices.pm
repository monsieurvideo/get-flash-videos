# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Mtvnservices;

use strict;
use FlashVideo::Utils;
use URI::Escape;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my $has_xml_simple = eval { require XML::Simple };
  if(!$has_xml_simple) {
    die "Must have XML::Simple installed to download Mtvnservices videos";
  }

  my $page_url = $browser->uri->as_string;

  if($embed_url !~ /mtvnservices/) {
    if($browser->content =~ m!(http://\w+.mtvnservices.com/(?:\w+/)?mgid:[a-z0-9:.-_]+)!) {
      $embed_url = $1;
    } else {
      die "Unable to find embedding URL";
    }
  }

  $browser->get($embed_url);
  die "Unable to get embed URL" unless $browser->response->code =~ /^30\d$/;

  my %param;
  my $location = $browser->response->header("Location");
  for(split /&/, (split /\?/, $location)[-1]) {
    my($n, $v) = split /=/;
    $param{$n} = uri_unescape($v);
  }

  die "No config_url/id found\n" unless $param{CONFIG_URL};

  $browser->get($param{CONFIG_URL});
  my $xml = XML::Simple::XMLin($browser->content);

  my $feed = uri_unescape($xml->{player}->{feed});
  die "Unable to find feed URL\n" unless $feed;

  $feed =~ s/\{([^}]+)\}/$param{$1}/g;

  return $self->handle_feed($feed, $browser, $page_url, $param{uri});
}

sub handle_feed {
  my($self, $feed, $browser, $page_url, $uri) = @_;

  $browser->get($feed);
  my $xml = XML::Simple::XMLin($browser->content);

  my $filename = title_to_filename($xml->{channel}->{title});

  my $items = $xml->{channel}->{item};
  my $item = ref $items eq 'ARRAY' ?
    (grep { $_->{guid}->{content} eq $uri } @$items)[0] :
    $items;

  my $mediagen_url = $item->{"media:group"}->{"media:content"}->{url};
  die "Unable to find mediagen URL\n" unless $mediagen_url;

  $browser->get($mediagen_url);
  $xml = XML::Simple::XMLin($browser->content);

  my $rendition = (grep { $_->{rendition} } ref $xml->{video}->{item} eq 'ARRAY'
    ?  @{$xml->{video}->{item}} : $xml->{video}->{item})[0]->{rendition};
  $rendition = [ $rendition ] unless ref $rendition eq 'ARRAY';

  my $url = (sort { $b->{bitrate} <=> $a->{bitrate} } @$rendition)[0]->{src};

  # I want to follow redirects now.
  $browser->allow_redirects;

  if($url =~ /^rtmp:/) {
    return {
      flv => $filename,
      rtmp => $url,
      pageUrl => $page_url,
      swfhash($browser, "http://media.mtvnservices.com/player/release/")
    };
  }

  return $url, $filename;
}

sub can_handle {
  my($self, $browser) = @_;

  return $browser->content =~ /mtvnservices\.com/i;
}

1;
