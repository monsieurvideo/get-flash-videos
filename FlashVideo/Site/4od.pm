# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::4od;

# Search support for 4oD (Channel 4 On Demand) on YouTube.
# Downloading is handled by FlashVideo::Site::Youtube.

use strict;
use FlashVideo::Utils;
use URI::Escape;

sub search {
  my ($self, $search) = @_;

  die "Must have XML::Simple installed to search YouTube"
    unless eval { require XML::Simple };

  # Use GData API to search
  # Note that 50 is the maximum value for max-results.
  my $gdata_template_url =
    "http://gdata.youtube.com/feeds/api/videos?q=%s&orderby=published&start-index=1&max-results=50&v=2";
  my $search_url = sprintf $gdata_template_url, uri_escape($search);

  my $browser = FlashVideo::Mechanize->new();

  $browser->get($search_url);

  if (!$browser->success) {
    die "Couldn't get YouTube search Atom XML: " . $browser->response->status_line();
  }

  # XML::Simple keys on 'id' and some other things by default which is
  # annoying.
  my $xml = eval { XML::Simple::XMLin($browser->content, KeyAttr => []) };
  
  die "Couldn't parse YouTube search Atom XML: $@" if $@;

  # Only care about actual 4od videos, where the author starts with '4od'.
  # (Channel 4 uses multiple authors or usernames depending on the type of
  # the video, for example 4oDDrama, 4oDFood and so on.)
  # Can't use the "author" search because specifying multiple authors
  # (comma separated) does not work, contrary to the GData documentation.
  my @matches = map { _process_4od_result($_) }
                grep { $_->{author}->{name} =~ /^4oD\w+$/i } @{ $xml->{entry} };

  return @matches;
}

sub _process_4od_result {
  my $feed_entry = shift;

  my $url = $feed_entry->{'media:group'}->{'media:player'}->{url};
  $url =~ s/&feature=youtube_gdata//;

  my $published_date = $feed_entry->{published};
  $published_date =~ s/T.*$//; # only care about date, not time

  my $title = $feed_entry->{'media:group'}->{'media:title'}->{content};
  my $description = $feed_entry->{'media:group'}->{'media:description'}->{content};

  my $result_name = "$title ($published_date)";

  return { name => $result_name, url => $url, description => $description };
}

1;
