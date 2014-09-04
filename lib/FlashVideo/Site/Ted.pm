# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Ted;
use strict;
use FlashVideo::Utils;
use FlashVideo::JSON;

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;

  my $basefilename;
  if ($browser->content =~ m{file":"http://download.ted.com/talks/([^-]+)}) {
    $basefilename = $1;
  } else {
    die "Unable to find download link";
  }

  # Determine all the different quality versions of the video
  my @bitrates = sort { $a <=> $b } $browser->content =~ m|"bitrate":([0-9]+)|g;

  my $video_title = extract_title($browser);

  # Get subtitles if requested.  Use the LANG variable to choose the language.
  # There is an intro to the video which isn't included in the subtitle timing info
  if ($prefs->subtitles) {
    my $lang = "";
    if ($browser->content =~ m{talkID = (\d+);}s || $browser->content =~ m{"id":(\d+),"duration"}) {
      my $talkID = $1;
      $ENV{LANG} =~ /^([^_]*)/;
      $lang = $1;
      if (!$lang) {
        info "Unable to determine your language, using English";
        $lang = "en";
      }
      info "Downloading subtitles";
      get_subtitles($browser, title_to_filename($video_title, 'srt'),
                    "http://www.ted.com/talks/subtitles/id/$talkID/lang/$lang/format/srt");
    } else {
      error "Unable to determine the talk ID, so can't get the subtitles";
    }
  }

  my $quality = $prefs->{quality};

  if ($quality eq "low") {
    $quality = "-light";
  } elsif ($quality eq "medium") {
    $quality = "-" . $bitrates[ int(@bitrates / 2) ] . "k" if @bitrates;
  } elsif ($quality eq "high") {
    $quality = "-480p";
    $quality = "-$bitrates[-1]k" if @bitrates;
  } else {
    die "Unknown quality setting";
  }

  my $url = "http://download.ted.com/talks/" . $basefilename . $quality . ".mp4";

  # the url will be redirected to the real one
  $browser->allow_redirects;
  return $url, title_to_filename($video_title);
}

sub get_subtitles {
  my ($browser, $filename, $url) = @_;

  $browser->mirror($url, $filename);

  if (!$browser->success) {
    error "Couldn't download subtitles: " . $browser->response->status_line;
    return;
  }
}

1;
