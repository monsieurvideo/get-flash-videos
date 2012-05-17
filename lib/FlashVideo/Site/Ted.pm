# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Ted;
use strict;
use FlashVideo::Utils;
use FlashVideo::JSON;

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;

  my $basefilename;
  if ($browser->content =~ m{<noscript.*download.ted.com/talks/([^.]+)\.mp4.*noscript>}s) {
    $basefilename = $1;
  } else {
    die "Unable to find download link";
  }

  # Get subtitles if requested.  Use the LANG variable to choose the language.
  # There is an intro to the video which isn't included in the subtitle timing info
  if ($prefs->subtitles) {
    my $lang = "";
    if ($browser->content =~ m{talkID = (\d+);}s) {
      my $talkID = $1;
      my $intro_time = 15000;
      if ($browser->content =~ m{introDuration:(\d+)}s) {
        $intro_time = int($1);
      } else {
        error "Can't find the intro duration, so guessing at 15 seconds.";
      }
      $ENV{LANG} =~ /^([^_]*)/;
      $lang = $1;
      if (!$lang) {
        info "Unable to determine your language, using English";
        $lang = "en";
      }
      info "Downloading subtitles";
      get_subtitles($browser, $basefilename . ".srt", $intro_time,
                    "http://www.ted.com/talks/subtitles/id/$talkID/lang/$lang/format/json");
    } else {
      error "Unable to determine the talk ID, so can't get the subtitles";
    }
  }

  my $quality = $prefs->{quality};
  if ($quality eq "low") {
    $quality = "-light";
  } elsif ($quality eq "medium") {
    $quality = "";
  } elsif ($quality eq "high") {
    $quality = "-480p";
  } else {
    die "Unknown quality setting";
  }

  my $url = "http://download.ted.com/talks/" . $basefilename . $quality . ".mp4";

  # the url will be redirected to the real one
  $browser->allow_redirects;
  return $url, $basefilename . ".mp4";
}

sub get_subtitles {
  my ($browser, $filename, $intro_time, $url) = @_;
  $browser->get($url);
  if (!$browser->success) {
    error "Couldn't download subtitles: " . $browser->response->status_line;
    return;
  }
  json_to_srt($browser->content, $filename, $intro_time);
}

# JSON to SRT subtitle conversion from zakflash

sub json_to_srt {
  my ($subdata, $filename, $intro_time) = @_;
  open (SRT, '>', $filename) or die "Can't open subtitles file $filename: $!";

  my $subtitle_count = 0;
  my $subdata = from_json($subdata);

  foreach my $subtitle (@{ $subdata->{captions} }) {
    $subtitle_count++; # SubRip starts at 1

    # SubRip format:
    # 1
    # 00:00:05,598 --> 00:00:07,131
    # (screaming)
    #
    # 2
    # 00:00:07,731 --> 00:00:09,298
    # D'oh!
    my ($srt_start, $srt_end) = convert_to_srt_time(
      $subtitle->{startTime} + $intro_time,
      $subtitle->{duration},
    );

    print SRT "$subtitle_count\n" .
          "$srt_start --> $srt_end\n" .
          "$subtitle->{content}\n\n";
  }

  close SRT;
}

sub convert_to_srt_time {
  my ($start, $duration) = @_;

  return format_srt_time($start),
         format_srt_time($start + $duration);
}

sub format_srt_time {
  my $time = shift;

  my $seconds = int($time / 1000);
  my $milliseconds = $time - ($seconds * 1_000);

  return sprintf "%02d:%02d:%02d,%03d", (gmtime $seconds)[2, 1, 0],
                                        $milliseconds;
}

1;
