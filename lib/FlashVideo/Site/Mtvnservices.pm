# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Mtvnservices;

# The following should work:
# - clip: http://www.thedailyshow.com/watch/wed-february-23-2011/exclusive---donald-rumsfeld-extended-interview-pt--1
# - clip: http://www.colbertnation.com/the-colbert-report-videos/381484/april-12-2011/jon-kyl-tweets-not-intended-to-be-factual-statements
# - full_episode: http://www.thedailyshow.com/full-episodes/wed-february-16-2011-brian-williams
# - full_episode: http://www.colbertnation.com/full-episodes/tue-march-1-2011-evan-osnos

use strict;
use FlashVideo::Utils;
use URI::Escape;

my $MTVN_URL = qr{http://\w+.mtvnservices.com/(?:\w+/)?mgid:[a-z0-9:.\-_]+};
my $MTVN_EPI_URL = qr{mgid:arc:episode:[a-z0-9:.\-_]+};
my $MTVN_ALT_URL = qr{mgid:[a-z0-9:.\-_]+};

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my $page_url = $browser->uri->as_string;

  if($embed_url !~ $MTVN_URL) {
    if($browser->content =~ m!($MTVN_URL)!) {
      $embed_url = $1;
    } elsif($browser->content =~ m!($MTVN_EPI_URL)!) {
      $embed_url = "http://media.mtvnservices.com/$1";
    } elsif($browser->content =~ m!($MTVN_ALT_URL)!) {
      $embed_url = "http://media.mtvnservices.com/$1";
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
  my $xml = from_xml_urlfix($browser);

  if($xml->{player}->{feed} && !ref $xml->{player}->{feed}) {
    my $feed = uri_unescape($xml->{player}->{feed});
    $feed =~ s/\{([^}]+)\}/$param{$1}/g;

    $browser->get($feed);

    return $self->handle_feed($browser->content, $browser, $page_url, $param{uri});
  } elsif(ref $xml->{player}->{feed}->{rss}) {
    # We must already have a feed embedded..
    return $self->handle_feed($xml->{player}->{feed}->{rss}, $browser, $page_url, $param{uri});
  } else {
    die "Unable to find feed\n";
  }
}

sub handle_full_episode {
  my($self, $items, $filename, $browser, $page_url, $uri) = @_;

  my @rtmpdump_commands;

  debug "Handling full episode";

  foreach (@$items) {
    my $item = $_;

    my $affect_counters = (grep { $_->{scheme} eq "urn:mtvn:affect_counters" } @{$item->{"media:group"}->{"media:category"}})[0];
    my $iscommercial = 0;
    if (defined $affect_counters && $affect_counters->{content} eq 'false') {
      $iscommercial = 1;
    }

    # I suppose we could add a setting to "enable" commercials, but for someone reason every rtmp download, they fail at 99%.
#    if ($isepisodesegment && !$iscommercial) {
    if (!$iscommercial) {
      my $mediagen_url = $item->{"media:group"}->{"media:content"}->{url};
      die "Unable to find mediagen URL\n" unless $mediagen_url;

      $browser->get($mediagen_url);
      my $xml = from_xml_urlfix($browser);

      my $rendition = (grep { $_->{rendition} } ref $xml->{video}->{item} eq 'ARRAY'
        ?  @{$xml->{video}->{item}} : $xml->{video}->{item})[0]->{rendition};
      $rendition = [ $rendition ] unless ref $rendition eq 'ARRAY';

      my $url = (sort { $b->{bitrate} <=> $a->{bitrate} } @$rendition)[0]->{src};

      my $mediagen_id;
      if($mediagen_url =~ /mediaGenEntertainment\.jhtml\?uri=([^&]+).*$/){
        $mediagen_id = $1;
      } elsif ($mediagen_url =~ /\?uri=([^&]+).*$/) {
        $mediagen_id = $1;
      } else {
        $mediagen_id = $mediagen_url;
      }

      # I want to follow redirects now.
      $browser->allow_redirects;

      push @rtmpdump_commands, {
        flv => title_to_filename($item->{"media:group"}->{"media:title"}),
        rtmp => $url,
        pageUrl => $item->{"link"},
        swfhash($browser, "http://media.mtvnservices.com/" . $mediagen_id)
      };
    }
  }

  return \@rtmpdump_commands;
}

sub handle_clip {
  my($self, $items, $filename, $browser, $page_url, $uri) = @_;

  debug "Handling clip";

  my $item = ref $items eq 'ARRAY' ?
    (grep { $_->{guid}->{content} eq $uri } @$items)[0] :
    $items;

  my $mediagen_url = $item->{"media:group"}->{"media:content"}->{url};
  die "Unable to find mediagen URL\n" unless $mediagen_url;

  $browser->get($mediagen_url);
  my $xml = from_xml_urlfix($browser);

  my $rendition = (grep { $_->{rendition} } ref $xml->{video}->{item} eq 'ARRAY'
    ?  @{$xml->{video}->{item}} : $xml->{video}->{item})[0]->{rendition};
  $rendition = [ $rendition ] unless ref $rendition eq 'ARRAY';

  my $url = (sort { $b->{bitrate} <=> $a->{bitrate} } @$rendition)[0]->{src};

  my $mediagen_id;
  if($mediagen_url =~ /mediaGenEntertainment\.jhtml\?uri=([^&]+).*$/){
    $mediagen_id = $1;
  } else {
    $mediagen_id = $mediagen_url;
  }

  # I want to follow redirects now.
  $browser->allow_redirects;

  if($url =~ /^rtmpe?:/) {
    return {
      flv => $filename,
      rtmp => $url,
      pageUrl => $page_url,
      swfhash($browser, "http://media.mtvnservices.com/" . $mediagen_id)
    };
  } else {
    return $url, $filename;
  }
}

sub handle_feed {
  my($self, $feed, $browser, $page_url, $uri) = @_;

  my $xml = ref $feed ? $feed : from_xml_urlfix($feed);

  my $filename = title_to_filename($xml->{channel}->{title});

  my $items = $xml->{channel}->{item};
  my $categories = ref $items eq 'ARRAY' ? @$items[0]->{"media:group"}->{"media:category"} : $items->{"media:group"}->{"media:category"};

  if (ref $categories eq 'ARRAY' && (
      (grep { $_->{scheme} eq "urn:mtvn:display:seo" } @$categories)[0]->{content} eq "" ||
      (grep { $_->{scheme} eq "urn:mtvn:content_type" } @$categories)[0]->{content} eq "Full Episode" ||
      (grep { $_->{scheme} eq "urn:mtvn:content_type" } @$categories)[0]->{content} eq "full_episode_segment")) {
    return $self->handle_full_episode($items, $filename, $browser, $page_url, $uri);
  } else {
    return $self->handle_clip($items, $filename, $browser, $page_url, $uri);
  }
}

sub can_handle {
  my($self, $browser, $url) = @_;

  return $browser->content =~ /mtvnservices\.com/i;
}

# Filter to avoid XML::Simple "not well-formed (invalid token)" error
# caused by '&' instead of '&amp;' inside url="..." values.

sub from_xml_urlfix {
  my($xmltext) = @_;
  $xmltext =~ s/&(?!amp;)/&amp;/g;  # too lax?
  return from_xml($xmltext);
}

1;
