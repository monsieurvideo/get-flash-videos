# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Seesaw;

use strict;
use FlashVideo::Utils;
use HTML::Entities qw(decode_entities);
use URI::Escape qw(uri_escape);

my @res = (
  { name => "lowResUrl",  resolution => [ 512, 288 ] },
  { name => "stdResUrl",  resolution => [ 672, 378 ] },
  { name => "highResUrl", resolution => [ 1024, 576 ] }
);

sub find_video {
  my ($self, $browser, $page_url, $prefs) = @_;

  # The videoplayerinfo info URL now appears as the Nth parameter to
  # player.init(), so just look for the videoplayerinfo directly, rather
  # than looking for player.init and the first parameter.
  my $player_info = ($browser->content =~ m{(/videoplayerinfo/\d+[^"]+)"})[0];

  # Remove escaped slashes
  (my $content = $browser->content) =~ s{\\/}{/}g;

  # Grab title and normalise
  my %seen; # avoid duplication in filenames
  
  # Annoyingly it's no longer easy to find out the series/season and
  # episode number.
  my %metadata = map { $_ => '' } qw(brandTitle seriesTitle programmeTitle);

  # Need to make this Dublin Core / ISO 15836 compliant.
  foreach my $metadata_item (keys %metadata) {
    if (my $value = ($content =~ m{<$metadata_item>(.*?)</$metadata_item>}isg)[0]) {
      $value = decode_entities($value);

      # Handle various metadata items being identical.
      next if $seen{$value};

      $metadata{$metadata_item} = $value;
    }
  }

  # Just in case series and episode numbers return.
  foreach my $item (values %metadata) {
    $item =~ s/^(?:(S)eries|(E)pisode) (\d+).*$/sprintf "%s%02d", $1, $2/ie;
  }

  my $title = join " - ", grep length,
                          @metadata{qw(brandTitle seriesTitle programmeTitle)};

  # Grab player info
  $browser->get($player_info);

  debug "Got player info URL $player_info";

  if (!$browser->success) {
    die "Couldn't get player info: " . $browser->response->status_line;
  }

  my @urls;
  for my $res(@res) {
    if($browser->content =~ /$res->{name}":\["([^"]+)/) {
      push @urls, { %$res, url => $1 };
    }
  }

  die "No video URLs found" unless @urls;

  my $rtmp = $prefs->quality->choose(@urls);

  my($app, $playpath, $query) = $rtmp->{url} =~ m{^\w+://[^/]+/(\w+/\w+)(/[^?]+)(\?.*)};
  my $prefix = "mp4";
  $prefix = "flv" if $playpath =~ /\.flv$/;

  if ($prefs->subtitles) {
    $browser->back;

    if ($browser->content =~ m{setConfig\('', '(/\w/\w+/\d{6,10}/\d+\.smi)'}) {
      my $subtitles_url = "http://www.seesaw.com$1";

      debug "Got Seesaw subtitles URL: $subtitles_url";

      $browser->get($subtitles_url);

      if ($browser->success) {
        my $srt_filename = title_to_filename($title, "srt"); 

        convert_sami_subtitles_to_srt($browser->content, $srt_filename);

        info "Wrote subtitles to $srt_filename";
      }
      else {
        info "Couldn't download subtitles: " . $browser->response->status_line;
      }
    }
    else {
      debug "No Seesaw subtitles available (or couldn't extract URL)";
    }
  }

  return {
    flv      => title_to_filename($title, $prefix),
    rtmp     => $rtmp->{url},
    app      => $app,
    playpath => "$prefix:$playpath$query"
  }
}

sub search {
  my($self, $search, $type) = @_;

  my $series  = $search =~ s/(?:series |\bs)(\d+)//i ? int $1 : "";
  my $episode = $search =~ s/(?:episode |\be)(\d+)//i ? int $1 : "";

  my $browser = FlashVideo::Mechanize->new;

  _update_with_content($browser,
    "http://www.seesaw.com/start.layout.searchsuggest:inputtextevent?search="
    . uri_escape($search));

  # Find links to programmes
  my @urls = map  {
    chomp(my $name = $_->text);
    { name => $name, url => $_->url_abs->as_string }
  } $browser->find_all_links(text_regex => qr/.+/);

  # Only use result which matched every word.
  # (Seesaw's search is useless, so this seems to be the best we can do).
  my @words = split " ", $search;
  @urls = grep { my $a = $_; @words == grep { $a->{name} =~ /\Q$_\E/i } @words } @urls;

  if(@urls == 1) {
    $browser->get($urls[0]->{url});
    # We are now at the episode page.
    my $main_title = ($browser->content =~ m{<h1>(.*?)</h1>}s)[0];
    $main_title =~ s/<[^>]+>//g;
    $main_title =~ s/\s+/ /g;

    # Parse the list of series
    my $cur_series = ($browser->content =~ /<li class="current">.*?>\w+ (\d+)/i)[0];
    if($main_title =~ s/\s*series (\d+)\s*//i && !$cur_series) {
      $cur_series = $1;
    }

    my %series = reverse(
      ($browser->content =~ m{<ul class="seriesList">(.*?)</ul>}i)[0]
      =~ /<li.*?href="\?([^"]+)".*?>\s*(?:series\s*)?([^<]+)/gi);

    # Go to the correct series
    my $episode_list;
    if($series && $cur_series ne $series) {
      if(!$series{$series}) {
        error "No such series number ($series).";
        return;
      }
      _update_with_content($browser, $series{$series});
      $episode_list = $browser->content;
      $cur_series = $series;

    } elsif(!$series && keys %series > 1) {
      my @series = sort { $a <=> $b } map { s/series\s+//i; $_ } keys %series;
      info "Viewing series $cur_series; series " . join(", ", @series) . " also available.";
      info "Search for 'seesaw $main_title series $series[0]' to view a specific series.";
    }

    if(!$episode_list) {
      # Grab the episodes for the current series from the page
      $episode_list = ($browser->content
        =~ m{<table id="episodeListTble">(.*?)</table>}is)[0];
    }

    # Parse list of episodes
    @urls = ();
    for my $episode_html($episode_list =~ m{<tr.*?</tr>}gis) {
      # Each table row here
      my %info;
      for(qw(number date title action)) {
        my $class = "episode" . ucfirst;
        $episode_html =~ m{<td class=['"]$class['"]>(.*?)</td>}gis
          && ($info{$_} = $1);
      }

      $info{number}   = ($info{number} =~ /ep\.?\w*\s*(\d+)/i)[0];
      $info{date}     = ($info{date}   =~ />(\w+[^<]+)/)[0];
      $info{number} ||= ($info{title}  =~ /ep\.?\w*\s*(\d+)/i)[0];
      $info{title}    = ($info{title}  =~ />\s*([^<].*?)\s*</s)[0];
      $info{url}      = ($info{action} =~ /href=['"]([^'"]+)/)[0];

      my $title = join " - ", $main_title,
        ($cur_series
          ? sprintf("S%02dE%02d", $cur_series, $info{number})
          : $info{number} ? sprintf("E%02d", $info{number})
        : ()), $info{title};

      my $result = {
        name => $title,
        url  => URI->new_abs($info{url}, $browser->uri)
      };

      if($episode && $info{number} == $episode) {
        # Exact match
        return $result;
      }

      push @urls, $result;
    }
  } else {
    info "Please specify a more specific title to download a particular programme." if @urls > 1;
  }

  return @urls;
}

sub _update_with_content {
  my($browser, $url) = @_;

  $browser->get($url,
    X_Requested_With => 'XMLHttpRequest',
    X_Prototype_Version => '1.6.0.3');

  my($content) = $browser->content =~ /content":\s*"(.*?)"\s*}/;
  $content = json_unescape($content);
  debug "Content is '$content'";
  $browser->update_html($content);
}

1;
