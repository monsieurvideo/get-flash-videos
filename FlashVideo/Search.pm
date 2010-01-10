# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Search;

use strict;
use Carp;

use FlashVideo::Utils;

# Sites which support searching
my @sites_with_search = ('4oD', 'GoogleVideoSearch');

sub search {
  my ($search, $max_per_site, $max_results) = @_;

  my @search_sites = map { /^FlashVideo::Site::/ ? $_ 
                                                 : "FlashVideo::Site::$_"; }
                     map { ucfirst lc } @sites_with_search;
 
  # If this is the dev version, preload search sites - not necessary for
  # combined because modules are already loaded.
  unless ($::SCRIPT_NAME) {
    eval "require $_" for @search_sites;
  }

  # If a user searches for "foo something", check to see if "foo" is a site
  # we support. If it is, only search that site.
  if ($search =~ /^(\w+) \w+/) {
    my $possible_site = ucfirst lc $1;

    debug "Checking to see if '$possible_site' in '$search' is a search-supported site.";

    my $possible_package = "FlashVideo::Site::$possible_site";

    eval "require $possible_package";

    if (UNIVERSAL::can($possible_package, "search")) {
      # Only search this site
      debug "Search for '$search' will only search $possible_site.";

      # Remove the site name from the search string
      $search =~ s/^\w+ //;

      return search_site($possible_package, $search, "site", $max_results);
    }
  }

  # Check to see if any plugins have a search function defined.
  my @plugins = main::get_installed_plugins();

  foreach my $plugin (@plugins) {
    $plugin =~ s/\.pm$//;

    my $plugin_package = "FlashVideo::Site::$plugin";

    eval "require $plugin_package";

    if (UNIVERSAL::can($plugin_package, "search")) {
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
