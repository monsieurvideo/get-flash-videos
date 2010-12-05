# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Thirteen;
use strict;
use FlashVideo::Utils;
use FlashVideo::JSON;

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;

  my $iframe;
  if ($browser->content =~ /<iframe src="([^"]*)" /) {
    $iframe = $1;
  } else {
    die "Couln't find iframe in " . $browser->uri->as_string;
  }

  my $url = 'http://www.thirteen.org' . $iframe;
  $browser->get($url);
  if (!$browser->success) {
    die "Couldn't download iframe $url: " . $browser->response->status_line;
  }

#  my $mediaID;
#  if ($browser->content =~ /var episodeMediaID = "([^"]*)";/) {
#    $mediaID = $1;
#  } else {
#    die "Couldn't find mediaID $url";
#  }

#  my $feed_url;
#  if ($browser->content =~ /var feedURL = "([^"]*)" + episodeMediaID + "([^"]*)";/) {
#    $feed_url = $1 . $mediaID;# . $2;
#  } else {
#    $feed_url = "http://feeds.theplatform.com/ps/JSON/PortalService/2.2/getReleaseList?PID=vbnrH_ew_gqKA2Npq_EbJQJKqOxpBnQA&query=KeywordsSearch|" . $mediaID;
#  }

  my $pid;
  if ($browser->content =~ /var pid = "([^"]*)";/) {
    $pid = $1;
  } elsif ($browser->uri->as_string =~ /&pid=([^&]*)&/) {
    $pid = $1;
  } else {
    die "Could not find pid for $url";
  }

  my $release_url;
  if ($browser->content =~ /so.addVariable\("releaseURL", "([^"]*)"+pid+"([^"]*)"\);/) {
    $release_url = $1 . $pid . $2;
  } else {
    $release_url = "http://release.theplatform.com/content.select?pid=" . $pid . "&amp;format=SMIL&amp;Tracking=true";
  }

  $browser->get($release_url);
  my $rtmp_url;
  if ($browser->response->is_redirect) {
    $rtmp_url = $browser->response->header("Location");
  } else {
    die "No redirect found for $release_url";
  }

  $rtmp_url =~ s/<break>//;

  my $filename;
  if ($rtmp_url =~ /mp4:(.*)\.mp4$/) {
    $filename = title_to_filename($1);
  } else {
    $filename = title_to_filename("");
  }

#  $browser->get($feed_url);
#  my $feed_data = from_json($browser->content);
#  debug($feed_data->{title});

  return {
    rtmp => $rtmp_url,
    flv => $filename,
  };
}

1;
