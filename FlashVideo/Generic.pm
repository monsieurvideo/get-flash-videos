# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Generic;
use FlashVideo::Utils;
use Memoize;
use LWP::Simple;

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
    (m|http://.+?(http://.+?\.flv)|) ? $1 : $_
  } ($browser->content =~ m'(http://.+?\.(?:flv|mp4))'g);
  if (@flv_urls) {
    memoize("LWP::Simple::head");
    @flv_urls = sort { (head($a))[1] <=> (head($b))[1] } @flv_urls;
    $possible_filename = (split /\//, $flv_urls[-1])[-1];
    $actual_url = $flv_urls[-1];

    $browser->head($actual_url);
    my $response = $browser->response;
    $got_url = 1 if $response->code == 200;
    my $redirects = 0;
    while ( ($response->code =~ /^30\d/) and ($response->header('Location'))
             and ($redirects < MAX_REDIRECTS) ) {
      my $url = $response->header('Location');
      $response = $browser->head($url);
      if ($response->code == 200) {
        $actual_url = $url;
        $got_url = 1;
        last;
      }
      $redirects++;
    }
  }

  if(!$got_url) {
    RE: for my $regex(
        qr{(?si)<embed.*flashvars=["']?([^"'>]+)},
        qr{(?si)<embed.*src=["']?([^"'>]+)},
        qr{(?si)<object[^>]*>.*?<param [^>]*value=["']?([^"'>]+)},
        # Attempt to handle scripts using flashvars / swfobject
        qr{(?si)<script[^>]*>(.*?)</script>}) {
      for my $param($browser->content =~ /$regex/g) {
        ($actual_url, $possible_filename) = find_file_param($browser, $param);
        if($actual_url) {
          $got_url = 1;
          last RE;
        }
      }
    }
  }

  my @filenames;
  push @filenames, $possible_filename if $possible_filename;
  push @filenames, $title if $title && $title !~ /\Q$possible_filename\E/i;
  push @filenames, get_video_filename() if !@filenames;
  
  return ($actual_url, @filenames) if $got_url;

  # XXX: link to bug tracker here / suggest update, etc...
  die "Couldn't extract Flash movie URL, maybe this site needs specific support adding?";
}

sub find_file_param {
  my($browser, $param) = @_;

  if($param =~ /(?:video|movie|file)['"]?\s*[=:]\s*['"]?([^&'"]+)/
      || $param =~ /['"=](.*?\.(?:flv|mp4))/) {
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
  my($browser, $file) = @_;

  my $uri = URI->new_abs($file, $browser->uri);

  if($uri) {
    $browser->head($uri);
    my $response = $browser->response;

    if($response->code == 200) {
      my $content_type = $response->header("Content-type");

      if($content_type =~ m!^(text|application/xml)!) {
        $browser->get($uri);
        return $1 if $browser->content =~ m!(http[-:/a-zA-Z0-9%_.?=&]+\.(flv|mp4))!;
      } else {
        return $uri->as_string;
      }
    }
  }

  return;
}

1;
