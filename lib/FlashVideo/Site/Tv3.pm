# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Tv3;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;

  my $content = $browser->content;

  if ($content !~ m/var\s+video\s*=\"[\/\*]([^"]+)\"\s*;/s) {
    die "Unable to extract file";
  }
  my $replace = $1;
  $replace =~ s/\*/\//sg;

  if ($content !~ m/src=['"](\/[A-Za-z0-9\/]+\/player[-\d]+\.min\.js\?v=\d*)['"]\+ord/s) {
    die "Unable to locate player module";
  }

  # The player always has a random component appended to a fixed
  # numeric prefix that will normally be 16 decimal digits long.
  my $ord = "";
  for (my $c = 0; $c < 16; $c++) {
    $ord .= int(rand(10));
  }
  my $player = $1 . $ord;

  # Default title is perfect.  We need to do this before we re-use the
  # browser to obtain other files.
  my $filename = title_to_filename(extract_title($browser));
  $filename ||= get_video_filename();

  debug "Trying to get player: $player";

  #
  # Getting the player.js isn't strictly necessary, but it allows us
  # to check assumptions, and not have to hard code the token - which
  # potentially might be changed from time to time.
  #

  my $smilPath = "/portals/0/video/smil1500-2.aspx";
  my $secureToken;
  {
    my $playerResponse = $browser->get($player);
    die "Failed to get player.js" if !$playerResponse->is_success();

    my $playerContent = $playerResponse->decoded_content();
    if ($playerContent !~ m/securetoken\s*:\s*\"([^\"]+)\"/s) {
      die "Unable to obtain securetoken";
    }
    $secureToken = $1;

    debug "Securetoken = $secureToken";

    my $smilPathRE = quotemeta($smilPath);
    if ($playerContent !~ m/$smilPathRE/s) {
      die "The expected SMIL path is not present";
    }
  }

  my $serverVar = "rtmpe://vod-geo.mediaworks.co.nz/vod/_definst_";
  my $locationVar = "mp4:tv3/" . $replace;

  my $info = undef;
  {
    my $smil = $smilPath . "?serverVar=" . $serverVar .
      "&locationVar=" . $locationVar . "&typeVar=mp4";

    debug "Trying to get SMIL: $smil";

    my $smilResponse = $browser->get($smil);
    die "Failed to get SMIL" if !$smilResponse->is_success();
    my $smilContent = $smilResponse->decoded_content();

    my $xml = $smilContent;
    my %rateMap = ();
    while ($xml =~ s/\<video src=\"([^\"]+)" system-bitrate=\"(\d+)\"//) {
      my $url = $1;
      my $bps = $2;

      debug "Available rate of ${bps} from $url";

      $rateMap{$bps} = { rate => $bps, src => $url };
    }

    my $quality = $prefs->{quality};
    $quality = "default" if !defined($quality);

    $info = $rateMap{$quality};
    if (!defined($info)) {
      my @rates = map { $rateMap{$_} } sort { $a <=> $b } keys %rateMap;

      my $option = undef;
      foreach my $try ("high", "medium", "low") {
        $option = pop(@rates) if (scalar(@rates) > 0);

        if ($try eq $quality) {
          # Matched
          $info = $option;
          last;
        }

        if (!defined($info)) {
          # Default to highest quality if no match seen.
          $info = $option;
        }
      }
    }

    if (!defined($info)) {
      die "Couldn't match the requested quality";
    }

    debug "Matching \"$quality\" quality at " . $info->{rate} .
      "bps with source \"" . $info->{src} . "\"";
  }

  my $rtmp = $serverVar . "/" . $info->{src};

  # It seems to be necessary to use --live, otherwise the stream
  # periodically jumps backwards.
  return {
    rtmp => $rtmp,
    live => "",
    token => $secureToken,
    swfVfy => "http://wa2.static.mediaworks.co.nz/video/jw/6.60/jwplayer.flash.swf",
    flv => $filename
   };
}

1;
