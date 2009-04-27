# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Generic;

use strict;
use constant MAX_REDIRECTS => 5;
use constant EXTENSIONS    => qr/\.(?:flv|mp4|mov|wmv)/;

use FlashVideo::Utils;
use Memoize;
use LWP::Simple;
use URI::Escape;

sub find_video {
  my ($self, $browser) = @_;

  # First strategy - identify all the Flash video files, and download the
  # biggest one. Yes, this is hacky.
  if (!$browser->success) {
    $browser->get($browser->response->header('Location'));
    die "Couldn't download URL: " . $browser->response->status_line
      unless $browser->success;
  }

  my ($possible_filename, $actual_url, $title, $got_url);
  if ($browser->content =~ /<title>(.*?)<\/title>/i) {
    $title = $1;
    $title =~ s/^(?:\w+\.com)[[:punct:] ]+//g;
    $title = title_to_filename($title); 
  }

  my @flv_urls = map {
    (m{http://.+?(http://.+?@{[EXTENSIONS]})}) ? $1 : $_
  } ($browser->content =~ m{(http://[-:/a-zA-Z0-9%_.?=&]+@{[EXTENSIONS]})}g);
  if (@flv_urls) {
    memoize("LWP::Simple::head");
    @flv_urls = sort { (head($a))[1] <=> (head($b))[1] } @flv_urls;
    $possible_filename = (split /\//, $flv_urls[-1])[-1];

    ($got_url, $actual_url) = url_exists($browser->clone, $flv_urls[-1]);
  }

  if(!$got_url) {
    RE: for my $regex(
        qr{(?si)<embed.*flashvars=["']?([^"'>]+)},
        qr{(?si)<embed.*src=["']?([^"'>]+)},
        qr{(?si)<object[^>]*>.*?<param [^>]*value=["']?([^"'>]+)},
        # Attempt to handle scripts using flashvars / swfobject
        qr{(?si)<script[^>]*>(.*?)</script>}) {
      for my $param($browser->content =~ /$regex/g) {
        ($actual_url, $possible_filename) = find_file_param($browser->clone, $param);

        if($actual_url) {
          ($got_url, $actual_url) = url_exists($browser->clone, $actual_url);
          last RE if $got_url;
        }
      }
    }
  }

  my @filenames;
  push @filenames, $possible_filename if $possible_filename;
  push @filenames, $title if $title && $title !~ /\Q$possible_filename\E/i;
  push @filenames, get_video_filename() if !@filenames;
  
  return ($actual_url, @filenames) if $got_url;

  die "No URLs found";
}

sub find_file_param {
  my($browser, $param) = @_;

  if($param =~ /(?:video|movie|file)['"]?\s*[=:]\s*['"]?([^&'"]+)/
      || $param =~ /(?:config|playlist)['"]?\s*[,:=]\s*['"]?(http[^'"&]+)/
      || $param =~ /['"=](.*?@{[EXTENSIONS]})/) {
    my $file = $1;

    my $actual_url = guess_file($browser, $file);
    if($actual_url) {
      my $possible_filename = (split /\//, $actual_url)[-1];

      return $actual_url, $possible_filename;
    }
  }
  
  return;
}

sub guess_file {
  my($browser, $file, $once) = @_;

  # Contains lots of URI encoding, so try escaping..
  $file = uri_unescape($file) if scalar(() = $file =~ /%[A-F0-9]{2}/g) > 3;

  my $uri = URI->new_abs($file, $browser->uri);

  info "Guessed $uri trying...";

  if($uri) {
    (my $exists, $uri) = url_exists($browser, $uri);

    if($exists) {
      my $content_type = $browser->response->header("Content-type");

      if($content_type =~ m!^(text|application/xml)!) {
        $browser->get($uri);

        # If this looks like HTML we have no hope of guessing right, so
        # give up now.
        return if $browser->content =~ /<html[^>]*>/i;

        if($browser->content =~ m!(http[-:/a-zA-Z0-9%_.?=&]+@{[EXTENSIONS]}
            # Grab any params that might be used for auth..
            (?:\?[-:/a-zA-Z0-9%_.?=&]+)?)!x) {
          # Found a video URL
          return $1;
        } elsif(!defined $once
            && $browser->content =~ m!(http[-:/a-zA-Z0-9%_.?=&]+)!) {
          # Try once more, one level deeper..
          return guess_file($browser, $1, 1);
        } else {
          info "Tried $uri, but no video URL found";
        }
      } else {
        return $uri->as_string;
      }
    }
  }

  return;
}

sub url_exists {
  my($browser, $url) = @_;

  $browser->head($url);
  my $response = $browser->response;
  return 1, $url if $response->code == 200;

  my $redirects = 0;
  while ( ($response->code =~ /^30\d/) and ($response->header('Location'))
      and ($redirects < MAX_REDIRECTS) ) {
    $url = $response->header('Location');
    $response = $browser->head($url);
    if ($response->code == 200) {
      return 1, $url;
    }
    $redirects++;
  }
}

1;
