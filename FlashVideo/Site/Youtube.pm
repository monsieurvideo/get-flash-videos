# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Youtube;

use strict;
use constant MAX_REDIRECTS => 5;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  if($embed_url !~ m!/watch!) {
    $browser->get($embed_url);
    if ($browser->response->header('Location') =~ m!/swf/.*video_id=([^&]+)!) {
      # We ended up on a embedded SWF
      $browser->get("http://www.youtube.com/watch?v=$1");
    }
  }

  if (!$browser->success) {
    if ($browser->response->code == 303) {
      # Lame age verification page - yes, we are grown up, please just give
      # us the video!
      my $confirmation_url = $browser->response->header('Location');
      print "Unfortunately, due to Youtube being lame, you have to have\n" .
            "an account to download this video.\n" .
            "Username: ";
      chomp(my $username = <STDIN>);
      print "Ok, need your password (will be displayed): ";
      chomp(my $password = <STDIN>);
      unless ($username and $password) {
        print "You must supply Youtube account details.\n";
        exit;
      }

      $browser->get("http://youtube.com/login");
      $browser->form_name("loginForm");
      $browser->set_fields(username => $username,
                           password => $password);
      $browser->submit();
      if ($browser->content =~ /your login was incorrect/) {
        print "Couldn't log you in, check your username and password.\n";
        exit;
      }

      $browser->get($confirmation_url);
      $browser->form_with_fields('next_url', 'action_confirm');
      $browser->field('action_confirm' => 'Confirm Birth Date');
      $browser->click_button(name => "action_confirm");

      if ($browser->response->code != 303) {
        print "Unexpected response from Youtube.\n";
        exit;
      }
      $browser->get($browser->response->header('Location'));
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

  my $video_id;
  if ($browser->content =~ /var pageVideoId = '(.+?)'/) {
    $video_id = $1;
  } else {
    die "Couldn't extract video ID";
  }

  my $t; # no idea what this parameter is but it seems to be needed
  if ($browser->content =~ /\W['"]?t['"]?: ?['"](.+?)['"]/) {
    $t = $1;
  } else {
    die "Couldn't extract mysterious t parameter";
  }

  my $file_functor = sub {
    my($type) = @_;

    if ($browser->content =~ /<meta name="title" content="(.+?)" ?\/? ?>/ or
        $browser->content =~ /<div id="vidTitle">\s+<span ?>(.+?)<\/span>/ or
        $browser->content =~ /<div id="watch-vid-title">\s*<div ?>(.+?)<\/div>/) {
      return title_to_filename($1, $type);
    } else {
      # Have to make up own our filename :( 
      return get_video_filename($type);
    }
  };

  my $fetcher = sub {
    my($url, $filename) = @_;
    my $browser = $browser->clone;
    my $response = $browser->get($url);
    my $redirects = 0;
    while ( ($response->code =~ /^30\d/) and ($response->header('Location'))
             and ($redirects < MAX_REDIRECTS) ) {
      my $url = $response->header('Location');
      $response = $browser->head($url);
      if ($response->code == 200) {
        return ($url, $filename);
      }
      $redirects++;
    }
    return;
  };

  # Try HD
  my @ret = $fetcher->("http://youtube.com/get_video?fmt=22&video_id=$video_id&t=$t",
    $file_functor->("mp4"));
  return @ret if @ret;

  # Try HQ
  my @ret = $fetcher->("http://youtube.com/get_video?fmt=18&video_id=$video_id&t=$t",
    $file_functor->("mp4"));
  return @ret if @ret;

  # Otherwise get normal
  my @ret = $fetcher->("http://youtube.com/get_video?video_id=$video_id&t=$t",
    $file_functor->());

  die "Unable to find video URL" unless @ret;

  return @ret;
}

1;
