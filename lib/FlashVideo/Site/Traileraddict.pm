# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Traileraddict;

use strict;
use FlashVideo::Utils;
use URI::Escape;

sub find_video {
  my ($self, $browser) = @_;

  my $video_id;
  if ($browser->content =~ m'/em[db]/(\d+)') {
    $video_id = $1;
  }
  else {
    die "Unable to get Traileraddict video ID";
  }

  my $video_info_url = "http://www.traileraddict.com/fvar.php?tid=$video_id";

  $browser->get($video_info_url);

  if (!$browser->success) {
    die "Couldn't download Traileraddict video info URL: " .
        $browser->response->status_line;
  }

  # Get video information -- this helpfully includes metadata which could
  # be useful for gfv's upcoming metadata feature.
  my %info = parse_video_info($browser->content);

  die "Couldn't find Traileraddict video URL" unless $info{fileurl};

  $browser->head($info{fileurl});
  if ($browser->response->is_redirect()) {
    $info{fileurl} = $browser->response->header('Location');
  }

  my $type = $info{fileurl} =~ /\.mp4/i ? 'mp4' : 'flv';
  
  return $info{fileurl}, title_to_filename($info{title}, $type);
}

sub parse_video_info {
  my $raw_video_info = shift;

  my %info;

  # Raw video info are URL-encoded key=value pairs.
  foreach my $pair (split /&/, $raw_video_info) {
    $pair = uri_unescape($pair);

    my ($name, $value) = split /=/, $pair;

    $info{$name} = $value;
  }

  return %info;
}

1;
