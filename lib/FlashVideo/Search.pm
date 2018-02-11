# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Search;

use strict;
use Carp;
use FlashVideo::Utils;

# Sites which support searching
my @sites_with_search = ('GoogleVideoSearch');

sub search {
  my ($class, $search, $max_per_site, $max_results) = @_;

  # Preload search sites
  my @search_sites = map { FlashVideo::URLFinder::_load($_) } @sites_with_search;

  # If a user searches for "foo something", check to see if "foo" is a site
  # we support. If it is, only search that site.
  if ($search =~ /^(\w+) \S+/) {
    my $possible_site = ucfirst lc $1;

    debug "Checking to see if '$possible_site' in '$search' is a search-supported site.";

    my $possible_package = FlashVideo::URLFinder::_load($possible_site);

    if ($possible_package->can("search")) {
      # Only search this site
      debug "Search for '$search' will only search $possible_site.";

      # Remove the site name from the search string
      $search =~ s/^\w+ //;

      return search_site($possible_package, $search, "site", $max_results);
    }
  }

  # Check to see if any plugins have a search function defined.
  my @plugins = App::get_flash_videos::get_installed_plugins();

  foreach my $plugin (@plugins) {
    $plugin =~ s/\.pm$//;

    my $plugin_package = FlashVideo::URLFinder::_load($plugin);

    if ($plugin_package->can("search")) {
      debug "Plugin '$plugin' has a search method.";

      unshift @search_sites, $plugin_package;
    }
    else {
      debug "Plugin '$plugin' doesn't have a search method.";
    }
  }

  # Call each site's search method - this includes plugins and sites
  # defined in @sites_with_search.
  my @results = map { search_site($_, $search, "all", $max_per_site) } @search_sites;

  # Return all results, trimming if necessary.
  trim_resultset(\@results, $max_results);

  return @results;
}

sub search_site {
  my($search_site, $search, $type, $max) = @_;

  debug "Searching '$search_site' for '$search'.";

  if (my @site_results = eval { $search_site->search($search, $type) }) {
    debug "Found " . @site_results . " results for $search.";

    trim_resultset(\@site_results, $max);
    return @site_results;
  }
  elsif($@) {
    info "Searching '$search_site' failed with: $@";
  }
  else {
    debug "No results found for '$search'.";
  }

  return ();
}

sub trim_resultset {
  my ($results, $max) = @_;

  croak "Must be supplied a reference to resultset" unless ref($results) eq 'ARRAY';
  croak "No max supplied" unless $max;

  if (@$results > $max) {
    debug "Found " . @$results . " results, trimming to $max.";
    splice @$results, $max;
  }
}

1;
