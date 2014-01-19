# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Ooyala;

use strict;
use FlashVideo::Utils;
use FlashVideo::JSON;
use File::Basename;
use HTML::Entities;
use URI::Escape;
use Data::Dumper;

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;

  debug $embed_url;

  my ($player_js) = uri_unescape(
    decode_entities(
      $browser->content =~ m{<(?:embed|script)[^>]+src=["'](http://player\.ooyala\.com/player\.(?:swf|js)[^'"]*)['"]}
    )
  );

  $player_js =~ s{player\.swf}{player.js};

  if (!$player_js && $browser->content =~ m{ooyala_video_player_data}) {
    my ($embed_code) = $browser->content =~ m{embed: *["']([^'"]*)['"]};
    if ($embed_code) {
      $player_js = "http://player.ooyala.com/player.js?embedCode=$embed_code";
    }
  }

  die 'Could not find player.js URL' unless $player_js;

  $browser->get($player_js);

  my ($mobile_player_js) =
    $browser->content =~ m{mobile_player_url *= *['"]([^'"]*)["']};
  $mobile_player_js .= 'unknown&domain=unknown';

  die 'Could not find mobile_player.js URL' unless $mobile_player_js;

  $browser->get($mobile_player_js);

  my ($streams) = $browser->content =~ m{streams *= *[^;]*eval\("(.*?)"\);};

  die 'Could not find streams in mobile_player.js' unless $streams;

  my $data = from_json(json_unescape($streams));

  my $title = $data->[0]{title};
  my $url;
  if ($prefs->{quality} =~ /high|ipad/) {
    $url = $data->[0]{ipad_url};
  } else {
     $url =$data->[0]{url};
  }

  # The streams being returned are redirects
  $browser->allow_redirects;

  return $url, title_to_filename($title, 'mp4');
}

sub can_handle {
  my($self, $browser, $url) = @_;

  return 1 if $url && URI->new($url)->host =~ /\.ooyala\.com$/;

  return 1 if $browser->content =~ m{ooyala_video_player_data};
  return $browser->content =~ m{<(?:embed|script)[^>]+src=["']http://player\.ooyala\.com/player\.(?:swf|js)[^'"]*['"]};
}

1;
