# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Youtube;

use strict;
use Encode;
use HTML::Entities;
use FlashVideo::Utils;
use URI::Escape;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  if($embed_url !~ m!youtube\.com/watch!) {
    $browser->get($embed_url);
    if ($browser->response->header('Location') =~ m!/swf/.*video_id=([^&]+)!
        || $embed_url =~ m!/v/([-_a-z0-9]+)!i
        || $browser->uri =~ m!v%3D([-_a-z0-9]+)!i) {
      # We ended up on a embedded SWF or other redirect page
      $embed_url = "http://www.youtube.com/watch?v=$1";
      $browser->get($embed_url);
    }
  }

  if (!$browser->success) {
    if ($browser->response->code == 303 
        && $browser->response->header('Location') =~ m!/verify_age|/accounts/!) {
      # Lame age verification page - yes, we are grown up, please just give
      # us the video!
      my $confirmation_url = $browser->response->header('Location');
      print "Unfortunately, due to Youtube being lame, you have to have\n" .
            "an account to download this video.\n" .
            "Username (Google Account Email): ";
      chomp(my $username = <STDIN>);
      print "Ok, need your password (will be displayed): ";
      chomp(my $password = <STDIN>);
      unless ($username and $password) {
        error "You must supply Youtube account details.";
        exit 1;
      }

      $browser->get("http://www.youtube.com/login");
      if ($browser->response->code != 303) {
        die "Unexpected response from Youtube login.\n";
      }

      my $real_login_url = $browser->response->header('Location');
      $browser->get($real_login_url);

      $browser->form_with_fields('Email', 'Passwd');
      $browser->set_fields(Email  => $username,
                           Passwd => $password);
      $browser->submit();

      if ($browser->content =~ /your login was incorrect/) {
        error "Couldn't log you in, check your username and password.";
        exit 1;
      } elsif ($browser->response->code == 302) {
        # expected, next step in login process
        my $check_cookie_url = $browser->response->header('Location');
        $browser->get($check_cookie_url);

        # and then another, html-only, non-http, redirection...
        if ($browser->content =~ /<meta.*"refresh".*?url=&#39;(.*?)&#39;"/i) {
          my $redirected = decode_entities($1);
          $browser->get($redirected);

          # If we weren't redirected to YouTube we might have a regional Google
          # site.
          if(URI->new($redirected)->host !~ /youtube/i) {
            if($browser->response->code == 302) {
              $browser->get($browser->response->header("Location"));
            } else {
              die "Did not find expected redirection";
            }
          }
        } else {
          die "Did not find expected redirection";
        }
      }
      else {
        die "Unexpected response during login";
      }

      # Now we go back to the video page, hopefully logged in...
      $browser->get($embed_url);

      # the confirmation url will always fail to show the video these days
      # AND it'll fail to show the button apparently.
      if ($browser->response->code == 303) {
        # this account hasn't been enabled for grownup videos yet
        my $real_confirmation_url = $browser->response->header('Location');
        $browser->get($real_confirmation_url);
        if ($browser->form_with_fields('next_url', 'action_confirm')) {
          $browser->field('action_confirm' => 'Confirm Birth Date');
          $browser->click_button(name => "action_confirm");

          if ($browser->response->code != 303) {
            die "Unexpected response from Youtube";
          }
          $browser->get($browser->response->header('Location'));
        }
      }
    }
    else {
      # Lame Youtube redirection to uk.youtube.com and so on.
      if ($browser->response->code == 302) {
        $browser->get($browser->response->header('Location'));
      }

      if (!$browser->success) {
        die "Couldn't download URL: " . $browser->response->status_line;
      }
    }
  }

  my $page_info = extract_info($browser);

  my $title;
  if ($page_info->{meta_title}) {
    $title = $page_info->{meta_title};
  } elsif ($browser->content =~ /<div id="vidTitle">\s+<span ?>(.+?)<\/span>/ or
      $browser->content =~ /<div id="watch-vid-title">\s*<div ?>(.+?)<\/div>/) {
    $title = $1;
  }

  # If the page contains fmt_url_map, then process this. With this, we
  # don't require the 't' parameter.
  if ($browser->content =~ /["']fmt_url_map["']:\s{0,3}["']([^"']+)["']/) {
    my $fmt_url_map = parse_youtube_format_url_map($1);

    if (!$title and $browser->uri->as_string =~ m'/user/.*?#') {
      # This is a playlist and getting the video title without the ID is
      # practically impossible because multiple videos are referenced in the
      # page. However, the encrypted (apparently) video ID is included in the
      # URL.
      my $video_id = (split /\//, $browser->uri->fragment)[-1];

      my %info = get_youtube_video_info($browser, $video_id);

      $title = $info{title};
    }
    
    my $url = $fmt_url_map->{ (sort { $b <=> $a } keys %$fmt_url_map)[0] };
    return $url, title_to_filename($title, "mp4");
  }

  my $video_id;
  if ($browser->content =~ /(?:var pageVideoId =|(?:CFG_)?VIDEO_ID'?\s*:)\s*'(.+?)'/
      || $embed_url =~ /v=([^&]+)/) {
    $video_id = $1;
  } else {
    die "Couldn't extract video ID";
  }

  # Try to get Youtube's info for this video - needed for some types of
  # video.
  my $video_page_url = $browser->uri()->as_string;

  if (my %info = get_youtube_video_info($browser, $video_id, $video_page_url)) {
    # Check for rtmp downloads
    if ($info{conn} =~ /^rtmp/) {
      $browser->back();

      # Get season and episode
      my ($season, $episode);

      if ($browser->content =~ m{<span(?: class=["']\w+["'])?>Season ?(\d+)</span>}) {
        $season = $1;
      }

      if ($browser->content =~ m{<span(?: class=["']\w+["'])?>Episode ?(\d+)</span>}) {
        $episode = $1;
      }
      
      if ($season and $episode) {
        $title .= sprintf " S%02dE%02d", $season, $episode;
      }

      # SWF verification, blah
      my $swf_url;
      if ($browser->content =~ /SWF_URL['"] ?: ?.{0,50}?(http:\/\/[^ ]+\.swf)/) {
        $swf_url = $1;
      }
      else {
        die "Couldn't extract SWF URL";
      }

      return {
        flv => title_to_filename($title),
        rtmp => $info{conn},
        swfhash($browser, $swf_url)
      };
    }
  }

  $browser->back();

  my $t; # no idea what this parameter is but it seems to be needed
  if ($browser->content =~ /\W['"]?t['"]?: ?['"](.+?)['"]/) {
    $t = $1;
  } else {
    die "Couldn't extract mysterious t parameter";
  }

  my $fetcher = sub {
    my($url, $filename) = @_;
    $url = url_exists($browser, $url, 1);
    return $url, $filename if $url;
    return;
  };

  # Try 1080p HD
  my @ret = $fetcher->("http://www.youtube.com/get_video?fmt=37&video_id=$video_id&t=$t",
    title_to_filename($title, "mp4"));
  return @ret if @ret;

  # Try HD
  @ret = $fetcher->("http://www.youtube.com/get_video?fmt=22&video_id=$video_id&t=$t",
    title_to_filename($title, "mp4"));
  return @ret if @ret;

  # Try HQ
  @ret = $fetcher->("http://www.youtube.com/get_video?fmt=18&video_id=$video_id&t=$t",
    title_to_filename($title, "mp4"));
  return @ret if @ret;

  # Otherwise get normal
  @ret = $fetcher->("http://www.youtube.com/get_video?video_id=$video_id&t=$t",
    title_to_filename($title));

  die "Unable to find video URL" unless @ret;

  $browser->allow_redirects;

  return @ret;
}

# Returns YouTube video information as key/value pairs for the specified
# video ID. The page that the video appears on can also be supplied. If not
# supplied, the function will create a suitable one.
sub get_youtube_video_info {
  my ($browser, $video_id, $url) = @_;

  $url ||= "http://www.youtube.com/watch?v=$video_id";

  my $video_info_url_template =
    "http://www.youtube.com/get_video_info?&video_id=%s&el=profilepage&ps=default&eurl=%s&hl=en_US";

  my $video_info_url = sprintf $video_info_url_template,
    uri_escape($video_id), uri_escape($url);

  $browser->get($video_info_url);

  return unless $browser->success;

  return parse_youtube_video_info($browser->content);
}

# Decode form-encoded key-value pairs into a hash for convenience.
sub parse_youtube_video_info {
  my $raw_info = shift;

  my %video_info;

  foreach my $raw_pair (split /&/, $raw_info) {
    my ($key, $value) = split /=/, $raw_pair;
    $value = uri_unescape($value);
    $value =~ s/\+/ /g;

    $video_info{$key} = $value;
  }

  return %video_info;
}

# Some YouTube pages contain a "fmt_url_map", a mapping of quality codes
# (or "formats") to URLs from where the video can be downloaded. This
# function returns a hash reference keyed on the format number. (Not ideal
# but this will allow people to easily select a specific quality in
# future.)
sub parse_youtube_format_url_map {
  my $raw_map = shift;

  my $map = {};

  # Simple format. Needs to be URI unescaped first.
  $raw_map = uri_unescape($raw_map);

  # Now split on comma as the record is structured like
  # $quality|$url,$quality|$url
  foreach my $pair (split /,/, $raw_map) {
    my ($format, $url) = split /\|/, $pair;

    # $url is double escaped so unescape again.
    $url = uri_unescape($url);

    $map->{$format} = $url;
  }
  
  return $map;
}

1;
