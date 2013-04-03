# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Generic;

use strict;
use FlashVideo::Utils;
use URI;
use FlashVideo::URLFinder;
use URI::Escape qw(uri_unescape);
use HTML::Entities qw(decode_entities);

my $video_re = qr!http[-:/a-z0-9%_.?=&]+@{[EXTENSIONS]}
                  # Grab any params that might be used for auth..
                  (?:\?[-:/a-z0-9%_.?=&]+)?!xi;

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;

  # First strategy - identify all the Flash video files, and download the
  # biggest one. Yes, this is hacky.
  if (!$browser->success) {
    $browser->get($browser->response->header('Location'));
    die "Couldn't download URL: " . $browser->response->status_line
      unless $browser->success;
  }

  my ($possible_filename, $actual_url, $title);
  $title = extract_title($browser);

  my @flv_urls = map {
    (m{http://.+?(http://.+?@{[EXTENSIONS]})}i) ? $1 : $_
  } ($browser->content =~ m{($video_re)}gi);
  if (@flv_urls) {
    require LWP::Simple;
    require Memoize;
    Memoize::memoize("LWP::Simple::head");
    @flv_urls = sort { (LWP::Simple::head($a))[1] <=> (LWP::Simple::head($b))[1] } @flv_urls;
    $possible_filename = (split /\//, $flv_urls[-1])[-1];

    # Un-escape URLs if necessary
    if ($flv_urls[-1] =~ /^http%3a%2f%2f/) {
      $flv_urls[-1] = uri_unescape($flv_urls[-1])
    }
    
    $actual_url = url_exists($browser->clone, $flv_urls[-1]);
  }

  my $filename_is_reliable;

  if(!$actual_url) {
    RE: for my $regex(
        qr{(?si)<embed.*?flashvars=["']?([^"'>]+)},
        qr{(?si)<embed.*?src=["']?([^"'>]+)},
        qr{(?si)<a[^>]* href=["']?([^"'>]+?@{[EXTENSIONS]})},
        qr{(?si)<object[^>]*>.*?<param [^>]*value=["']?([^"'>]+)},
        qr{(?si)<object[^>]*>(.*?)</object>},
        # Attempt to handle scripts using flashvars / swfobject
        qr{(?si)<script[^>]*>(.*?)</script>}) {

      for my $param($browser->content =~ /$regex/gi) {
        (my $url, $possible_filename, $filename_is_reliable) = find_file_param($browser->clone, $param, $prefs);

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
        $iframe = decode_entities($iframe);
        debug "Found iframe: $iframe";
        my $sub_browser = $browser->clone;
        $sub_browser->get($iframe);
        # Recurse!
        my($package, $possible_url) = FlashVideo::URLFinder->find_package($iframe, $sub_browser);

        # Before fetching the url, give the package a chance
        if($package->can("pre_find")) {
          $package->pre_find($sub_browser);
        }

        info "Downloading $iframe";
        $sub_browser->get($iframe);

        my($actual_url, @suggested_fnames) = eval {
          $package->find_video($sub_browser, $possible_url, $prefs);
        };
        return $actual_url, @suggested_fnames if $actual_url;
      }
    }
  }

  my @filenames;
  
  return $actual_url, $possible_filename if $filename_is_reliable;

  $possible_filename =~ s/\?.*//;
  # The actual filename, provided it looks like it might be reasonable
  # (not just numbers)..
  push @filenames, $possible_filename if $possible_filename
    && $possible_filename !~ /^[0-9_.]+@{[EXTENSIONS]}$/;

  # The title of the page, if it isn't similar to the filename..
  my $ext = substr(($actual_url =~ /(@{[EXTENSIONS]})$/)[0], 1);
  push @filenames, title_to_filename($title, $ext) if
    $title && $title !~ /\Q$possible_filename\E/i;

  # A title with just the timestamp in it..
  push @filenames, get_video_filename() if !@filenames;
  
  return $actual_url, @filenames if $actual_url;

  # As a last ditch attempt, download the SWF file as in some cases, sites
  # use an SWF movie file for each FLV.

  # Get SWF URL(s)
  my %swf_urls;

  if (eval { require URI::Find }) {
    my $finder = URI::Find->new(
      sub { $swf_urls{$_[1]}++ if $_[1] =~ /\.swf$/i }
    );
    $finder->find(\$browser->content);
  }
  else {
    # Extract URLs in a frail way.
    my $content = $browser->content;
    while($content =~ m{(http://[^ "']+?\.swf)}ig) {
      $swf_urls{$1}++;
    }
  }

  if (%swf_urls) {
    foreach my $swf_url (keys %swf_urls) {
      if (my ($flv_url, $title) = search_for_flv_in_swf($browser, $swf_url)) {
        return $flv_url, title_to_filename($title);
      }
    }
  }

  die "No URLs found";
}

sub search_for_flv_in_swf {
  my ($browser, $swf_url) = @_;

  $browser = $browser->clone();

  $browser->get($swf_url);

  if (!$browser->success) {
    die "Couldn't download SWF URL $swf_url: " .
      $browser->response->status_line();
  }

  # SWF data might be compressed.
  my $swf_data = $browser->content;

  if ('C' eq substr $swf_data, 0, 1) {
    if (eval { require Compress::Zlib }) {
      $swf_data = Compress::Zlib::uncompress(substr $swf_data, 8);
    }
    else {
      die "Compress::Zlib is required to uncompress compressed SWF files.\n";
    }
  }

  if ($swf_data =~ m{(http://.{10,300}?\.flv)}i) {
    my $flv_url = $1;

    my $filename = uri_unescape(File::Basename::basename(URI->new($flv_url)->path()));
    $filename =~ s/\.flv$//i;

    return ($flv_url, $filename);
  }

  return;
}

sub find_file_param {
  my($browser, $param, $prefs) = @_;

  for my $file($param =~ /(?:video|movie|file|path)_?(?:href|src|url)?['"]?\s*[=:,]\s*['"]?([^&'" ]+)/gi,
      $param =~ /(?:config|playlist|options)['"]?\s*[,:=]\s*['"]?(http[^'"&]+)/gi,
      $param =~ /['"=](.*?@{[EXTENSIONS]})/gi,
      $param =~ /([^ ]+@{[EXTENSIONS]})/gi,
      $param =~ /SWFObject\(["']([^"']+)/) {

    debug "Found $file";

    my ($actual_url, $filename, $filename_is_reliable) = guess_file($browser, $file, '', $prefs);

    if(!$actual_url && $file =~ /\?(.*)/) {
      # Maybe we have query params?
      debug "Trying query param on $1";

      for my $query_param(split /[;&]/, $1) {
        my($query_key, $query_value) = split /=/, $query_param;
        debug "Found $query_value from $query_key";

        ($actual_url, $filename, $filename_is_reliable)
          = guess_file($browser, $query_value, '', $prefs);

        last if $actual_url;
      }
    }

    if($actual_url) {
      my $possible_filename = $filename || (split /\//, $actual_url)[-1];

      return $actual_url, $possible_filename, $filename_is_reliable;
    }
  }

  if($param =~ m{(rtmp://[^ &"']+)}) {
    info "This looks like RTMP ($1), no generic support yet..";
  }
  
  return;
}

sub guess_file {
  my($browser, $file, $once, $prefs) = @_;

  # Contains lots of URI encoding, so try escaping..
  $file = uri_unescape($file) if scalar(() = $file =~ /%[A-F0-9]{2}/gi) > 3;

  my $orig_uri = URI->new_abs($file, $browser->uri);

  info "Guessed $orig_uri trying...";

  if($orig_uri) {
    my $uri = url_exists($browser->clone, $orig_uri);

    if($uri) {
      # Check to see if this URL is for a supported site.
      my ($package, $url) = FlashVideo::URLFinder->find_package($uri,
        $browser->clone);

      if($package && $package ne __PACKAGE__) {
        debug "$uri is supported by $package.";
        (my $browser_on_supported_site = $browser->clone())->get($uri);
        return $package->find_video($browser_on_supported_site, $uri, $prefs), 1;
      }

      my $content_type = $browser->response->header("Content-type");

      if($content_type =~ m!^(text|application/xml)!) {
        # Just in case someone serves the video itself as text/plain.
        $browser->add_header("Range", "bytes=0-10000");
        $browser->get($uri);
        $browser->delete_header("Range");

        if(FlashVideo::Downloader->check_magic($browser->content)
            || $uri =~ m!$video_re!) {
          # It's a video..
          debug "Found a video at $uri";
          return $uri;
        }

        # If this looks like HTML we have no hope of guessing right, so
        # give up now.
        return if $browser->content =~ /<html[^>]*>/i;

        if($browser->content =~ m!($video_re)!) {
          # Found a video URL
          return $1;
        } elsif(!defined $once
            && $browser->content =~ m!(http[-:/a-zA-Z0-9%_.?=&]+)!i) {
          # Try once more, one level deeper..
          return guess_file($browser, $1, 1, $prefs);
        } else {
          info "Tried $uri, but no video URL found";
        }
      } elsif($content_type =~ m!application/! && $uri ne $orig_uri) {
        # We were redirected, maybe something in the new URL?
        return((find_file_param($browser, $uri))[0]);
      } else {
        return $uri->as_string;
      }
    } elsif(not defined $once) {
      # Try using the location of the .swf file as the base, if it's different.
      if($browser->content =~ /["']([^ ]+\.swf)/) {
        my $swf_uri = URI->new_abs($1, $browser->uri);
        if($swf_uri) {
          my $new_uri = URI->new_abs($file, $swf_uri);
          debug "Found SWF: $swf_uri -> $new_uri";
          if($new_uri ne $uri) {
            return guess_file($browser, $new_uri, 1, $prefs);
          }
        }
      }
    }
  }

  return;
}

1;
