# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Tv3;

use strict;
use FlashVideo::Utils;

my $encode_rates = {
  "low" => {
    speed => 300,
    flag => undef,
    downgrade => undef
   },
  "medium" => {
    speed => 700,
    flag => "sevenHundred",
    downgrade => "low"
   },
  "high" => {
    speed => 1500,
    flag => "fifteenHundred",
    downgrade => "medium"
   }
 };

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;

  if ($browser->content !~ m/var\s+video\s*=\"\*([^"]+)\"\s*;/s) {
    die "Unable to extract file";
  }
  my $replace = $1;
  $replace =~ s/\*/\//sg;

  my $quality = $prefs->{quality};
  my $encodeRate = $encode_rates->{$quality};
  if (!defined($encodeRate)) {
    foreach my $rate (values(%$encode_rates)) {
      if ($rate->{speed} eq $quality) {
        $encodeRate = $rate;
        last;
      }
    }
  }

  my $content = undef;
  while (defined($encodeRate)) {
    debug "Trying to use encoding rate " . $encodeRate->{speed};

    my $flag = $encodeRate->{flag};
    if (defined($flag)) {
      $content = $browser->content if !defined($content);
      if ($content !~ m/flashvars\.$flag\s*=\s*"yes"/s) {
        my $downgrade = $encodeRate->{downgrade};
        if (!defined($downgrade)) {
          $encodeRate = undef;
          last;
        }

        debug "Rate " . $encodeRate->{speed} .
          " isn't available, dowgrading to " . $downgrade;

        $encodeRate = $encode_rates->{$downgrade};
        next;
      }
    }
    last;
  }

  if (!defined($encodeRate)) {
    die "Couldn't match the requested quality";
  }

  my $conSpeed = $encodeRate->{speed};

  my $rtmp = "rtmpe://nzcontent.mediaworks.co.nz:80/tv3/_definst_/mp4:" .
    $replace . "_" . $conSpeed . "K";

  # Default title is perfect.
  my $filename = title_to_filename(extract_title($browser));
  $filename ||= get_video_filename();

  return {
    rtmp => $rtmp,
    swfVfy => "http://static.mediaworks.co.nz/video/6.9/videoPlayer6.9.83.swf?rnd=1932311212",
    flv => $filename
   };
}

1;
