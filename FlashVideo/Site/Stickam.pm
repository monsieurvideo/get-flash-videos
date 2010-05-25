# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Stickam;

use strict;
use FlashVideo::Utils;

sub find_video {
  my($self, $browser, $embed_url, $prefs) = @_;

  my $perfomer_id;

  if ($browser->content =~ /profileUserId=(\d+)/) {
    $perfomer_id = $1;  
  }
  else {
    die "Can't get performer ID";
  }

  my $filename;
  if ($browser->content =~ /userName=([^&]+)/) {
    $filename = $1;
  }
  else {
    $filename = $perfomer_id;
  }

  my $stream_info_url = sprintf
    "http://player.stickam.com/servlet/flash/getChannel?" .
    "type=join&performerID=%d", $perfomer_id;

  $browser->get($stream_info_url);

  if (!$browser->success) {
    die "Couldn't get stream info: " . $browser->response->status_line;
  }

  my %stream_info;

  foreach my $pair (split /&/, $browser->content) {
    my ($name, $value) = split /=/, $pair;

    # Special handling for server IP, as multiple can be specified.
    if ($name eq 'freeServerIP') {
      $value = (split /,/, $value)[0];
    }
    
    $stream_info{$name} = $value;
  }

  if ($stream_info{errorCode}) {
    die "Stickam returned error $stream_info{errorCode}: $stream_info{errorMessage}";
  }

  my $rtmp_stream_url = sprintf
    "rtmp://%s/video_chat2_stickam_peep/%d/public/mainHostFeed",
    $stream_info{freeServerIP},
    $stream_info{channelID};

  return {
    rtmp => $rtmp_stream_url,
    flv => title_to_filename($filename),
    live => '',
    conn => [
      'O:1',
      "NS:channel:$perfomer_id",
      'O:1',
    ],
    swfhash($browser,
      "http://player.stickam.com/flash/stickam/stickam_simple_video_player.swf")
  };
}

1;
