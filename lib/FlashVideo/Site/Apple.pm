# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Apple;
use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;

  if(!FlashVideo::Downloader->check_file($browser->content)) {
    # We weren't given a quicktime link, so find one..
    my @urls = $browser->content =~ /['"]([^'"]+\.mov)(?:\?[^'"]+)?['"]/g;
    die "No .mov URLs found on page" unless @urls;
    debug "Found URLs: @urls";

    my $redirect_url = $prefs->quality->choose(map {
        /(\d+p?)\.mov/ && {
          url => $_,
          resolution => $prefs->quality->format_to_resolution($1)
        }
      } @urls
    )->{url};

    $browser->get($redirect_url);
  }

  my $url = $self->handle_mov($browser);
  my $filename = ($url->path =~ m{([^/]+)$})[0];

  return $url, $filename;
}

# This could move into generic if we see other sites using quicktime links like
# this..
sub handle_mov {
  my ($self, $browser) = @_;

  # I'm an iPhone (not a PC)
  $browser->agent("Apple iPhone OS v2.0.1 CoreMedia v1.0.0.5B108");

  if($browser->content =~ /url\s*\0+[\1-,]*(.*?)\0/) {
    return URI->new_abs($1, $browser->uri)
  } else {
    die "Cannot find link in .mov";
  }
}

sub can_handle {
  my($self, $browser, $url) = @_;

  return $url =~ m{apple\.com/trailers/} || $url =~ m{movies\.apple\.com};
}

1;
