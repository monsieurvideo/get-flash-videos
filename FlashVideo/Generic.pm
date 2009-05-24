# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Generic;

use strict;
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
  $title = extract_title($browser);

  my @flv_urls = map {
    (m{http://.+?(http://.+?@{[EXTENSIONS]})}i) ? $1 : $_
  } ($browser->content =~ m{(http://[-:/a-zA-Z0-9%_.?=&]+@{[EXTENSIONS]})}gi);
  if (@flv_urls) {
    memoize("LWP::Simple::head");
    @flv_urls = sort { (head($a))[1] <=> (head($b))[1] } @flv_urls;
    $possible_filename = (split /\//, $flv_urls[-1])[-1];

    $actual_url = url_exists($browser->clone, $flv_urls[-1]);
  }

  if(!$actual_url) {
    RE: for my $regex(
        qr{(?si)<embed.*?flashvars=["']?([^"'>]+)},
        qr{(?si)<embed.*?src=["']?([^"'>]+)},
        qr{(?si)<object[^>]*>.*?<param [^>]*value=["']?([^"'>]+)},
        qr{(?si)<object[^>]*>(.*?)</object>},
        # Attempt to handle scripts using flashvars / swfobject
        qr{(?si)<script[^>]*>(.*?)</script>}) {

      for my $param($browser->content =~ /$regex/gi) {
        (my $url, $possible_filename) = find_file_param($browser->clone, $param);

        if($url) {
          my $resolved_url = url_exists($browser->clone, $url);
          if($resolved_url) {
            $actual_url = $resolved_url;
            last RE;
          }
        }
      }
    }

    if(!$actual_url) {
      for my $iframe($browser->content =~ /<iframe[^>]+src=["']?([^"'>]+)/gi) {
        $iframe = URI->new_abs($iframe, $browser->uri);
        debug "Found iframe: $iframe";
        my $sub_browser = $browser->clone;
        $sub_browser->get($iframe);
        ($got_url, $actual_url) = eval { $self->find_video($sub_browser) };
      }
    }
  }

  my @filenames;

  # The actual filename, provided it looks like it might be reasonable
  # (not just numbers)..
  push @filenames, $possible_filename if $possible_filename
    && $possible_filename !~ /^[0-9_.]+@{[EXTENSIONS]}$/;

  # The title of the page, if it isn't similar to the filename..
  my $ext = ($actual_url =~ /(\w+)$/)[0];
  push @filenames, title_to_filename($title, $ext) if
    $title && $title !~ /\Q$possible_filename\E/i;

  # A title with just the timestamp in it..
  push @filenames, get_video_filename() if !@filenames;
  
  return ($actual_url, @filenames) if $got_url;

  die "No URLs found";
}

sub find_file_param {
  my($browser, $param) = @_;

  if($param =~ /(?:video|movie|file)['"]?\s*[=:,]\s*['"]?([^&'" ]+)/i
      || $param =~ /(?:config|playlist|options)['"]?\s*[,:=]\s*['"]?(http[^'"&]+)/i
      || $param =~ /['"=](.*?@{[EXTENSIONS]})/i
      || $param =~ /([^ ]+@{[EXTENSIONS]})/i
      || $param =~ /SWFObject\(["']([^"']+)/) {
    my $file = $1;

    my $actual_url = guess_file($browser, $file);
    if($actual_url) {
      my $possible_filename = (split /\//, $actual_url)[-1];

      return $actual_url, $possible_filename;
    }
  }

  if($param =~ m{(rtmp://[^ &"']+)}) {
    info "This looks like RTMP ($1), no generic support yet..";
  }
  
  return;
}

sub guess_file {
  my($browser, $file, $once) = @_;

  # Contains lots of URI encoding, so try escaping..
  $file = uri_unescape($file) if scalar(() = $file =~ /%[A-F0-9]{2}/gi) > 3;

  my $orig_uri = URI->new_abs($file, $browser->uri);

  info "Guessed $orig_uri trying...";

  if($orig_uri) {
    my $uri = url_exists($browser, $orig_uri);

    if(defined $uri) {
      my $content_type = $browser->response->header("Content-type");

      if($content_type =~ m!^(text|application/xml)!) {
        $browser->get($uri);

        # If this looks like HTML we have no hope of guessing right, so
        # give up now.
        return if $browser->content =~ /<html[^>]*>/i;

        if($browser->content =~ m!(http[-:/a-z0-9%_.?=&]+@{[EXTENSIONS]}
            # Grab any params that might be used for auth..
            (?:\?[-:/a-z0-9%_.?=&]+)?)!xi) {
          # Found a video URL
          return $1;
        } elsif(!defined $once
            && $browser->content =~ m!(http[-:/a-zA-Z0-9%_.?=&]+)!i) {
          # Try once more, one level deeper..
          return guess_file($browser, $1, 1);
        } else {
          info "Tried $uri, but no video URL found";
        }
      } elsif($content_type =~ m!application/! && $uri ne $orig_uri) {
        # We were redirected, maybe something in the new URL?
        return((find_file_param($browser, $uri))[0]);
      } else {
        return $uri->as_string;
      }
    }
  }

  return;
}

1;
