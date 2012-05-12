# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Ted;
use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;

  my $filename;
  if ($browser->content =~ m{<noscript.*download.ted.com/talks/([^.]+)\.mp4.*noscript>}s) {
    $filename = $1;
  } else {
    die "Unable to find download link";
  }

  # Get subtitles if requested
  my $lang = "";
  my $quality = $prefs->{quality};
  if ($prefs->subtitles) {
    if ($quality eq "low") {
      $quality = "-low";
    } elsif ($quality eq "high") {
      $quality = "-480p";
    } else {
      die "subtitles aren't available for this quality level, only high or low";
    }
    $ENV{"LANG"} =~ /^([^_]*)/;
    $lang = $1;
    if ($lang eq "") {
      info "Unable to determine your language, using English";
      $lang = "en";
    }
    $lang = "-" . $lang;
  } else {
    if ($quality eq "low") {
      $quality = "-light";
    } elsif ($quality eq "medium") {
      $quality = "";
    } elsif ($quality eq "high") {
      $quality = "-480p";
    } else {
      die "Unknown quality setting";
    }
  }
  $filename .= $quality . $lang . ".mp4";


  my $url = "http://download.ted.com/talks/$filename";

  # the url will be redirected to the real one
  $browser->allow_redirects;
  return $url, $filename;
}

1;
