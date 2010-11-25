# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Pbs;

use strict;
use warnings;

use FlashVideo::Utils;

use Crypt::Rijndael;
use MIME::Base64 qw(decode_base64);

=pod

Programs that work:
    - http://video.pbs.org/video/1623753774/
    - http://www.pbs.org/wnet/nature/episodes/revealing-the-leopard/full-episode/6084/
    - http://www.pbs.org/wgbh/nova/ancient/secrets-stonehenge.html
    - http://www.pbs.org/wnet/americanmasters/episodes/lennonyc/outtakes-jack-douglas/1718/
    - http://www.pbs.org/wnet/need-to-know/video/need-to-know-november-19-2010/5189/
    - http://www.pbs.org/newshour/bb/transportation/july-dec10/airport_11-22.html

Programs that don't work yet:
    - http://www.pbs.org/wgbh/pages/frontline/woundedplatoon/view/
    - http://www.pbs.org/wgbh/roadshow/rmw/RMW-003_200904F02.html

TODO:
    - subtitles

=cut

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;

  my ($media_id) = $browser->uri->as_string =~ m[
    ^http://video\.pbs\.org/video/(\d+)
  ]x;
  unless (defined $media_id) {
    ($media_id) = $browser->content =~ m[
      http://video\.pbs\.org/widget/partnerplayer/(\d+)
    ]x;
  }
  unless (defined $media_id) {
    ($media_id) = $browser->content =~ m[
      /embed-player[^"]+\bepisodemediaid=(\d+)
    ]x;
  }
  unless (defined $media_id) {
    ($media_id) = $browser->content =~ m[var videoUrl = "([^"]+)"];
  }
  unless (defined $media_id) {
    my ($pap_id, $youtube_id) = $browser->content =~ m[
      \bDetectFlashDecision\ \('([^']+)',\ '([^']+)'\);
    ]x;
    if ($youtube_id) {
      debug "Youtube ID found, delegating to Youtube plugin\n";
      my $url = "http://www.youtube.com/v/$youtube_id";
      require FlashVideo::Site::Youtube;
      return FlashVideo::Site::Youtube->find_video($browser, $url, $prefs);
    }
  }
  die "Couldn't find media_id\n" unless defined $media_id;
  debug "media_id: $media_id\n";

  $browser->get("http://video.pbs.org/videoPlayerInfo/$media_id");

  my $xml = $browser->content;
  $xml =~ s/&/&amp;/g;
  my $href = from_xml($xml);
  my $release_url = $href->{releaseURL};

  unless ($release_url =~ m[^https?://]) {
    debug "encrypted release url: $release_url\n";
    my ($type, $iv, $ciphertext) = split '\$', $release_url, 3;
    $release_url = undef;

    # From http://www-tc.pbs.org/video/media/swf/PBSPlayer.swf
    my $key = 'RPz~i4p*FQmx>t76';

    my $cipher = Crypt::Rijndael->new($key, Crypt::Rijndael::MODE_CBC);
    $iv = pack 'H*', $iv if 32 == length $iv;
    $cipher->set_iv($iv);

    $release_url = $cipher->decrypt(decode_base64($ciphertext));
    $release_url =~ s/\s+$//;
  }
  debug "unencrypted release url: $release_url\n";

  $browser->get($release_url);

  my $rtmp_url = $browser->res->header('location')
    or die "Couldn't find stream url\n";
  $rtmp_url =~ s/<break>//;

  my ($file) = $rtmp_url =~ m{([^/]+)$};

  return {
    rtmp    => $rtmp_url,
    pageUrl => $embed_url,
    swfUrl  => 'http://www-tc.pbs.org/video/media/swf/PBSPlayer.swf?18809',
    flv     => $file,
  };
}

1;
