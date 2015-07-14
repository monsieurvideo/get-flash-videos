# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Pbs;

use strict;
use warnings;
use Encode;
use FlashVideo::Utils;
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

our $VERSION = '0.02';
sub Version() { $VERSION; }

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;

  die "Must have Crypt::Rijndael installed to download from PBS"
    unless eval { require Crypt::Rijndael };

  my ($media_id) = $embed_url =~ m[http://video\.pbs\.org/videoPlayerInfo/(\d+)]x;
  unless (defined $media_id) {
    ($media_id) = $browser->uri->as_string =~ m[
      ^http://video\.pbs\.org/video/(\d+)
    ]x;
  }
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
    ($media_id) = $browser->content =~ m[pbs_video_id_\S+" value="([^"]+)"];
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

  $browser->allow_redirects;
  $browser->get("http://video.pbs.org/videoPlayerInfo/$media_id");
  debug "fetched: $media_id\n";
  
  my $xml = $browser->content;
  debug "retrieved xml: $media_id\n";
  
  $xml = encode('utf-8', $xml);
  debug "encode: $media_id\n";
  
  #$xml =~ s/&/&amp;/g; # not sure this is needed anymore
  #debug "decoded ampersands: $media_id\n";
  
  my $href = from_xml($xml);
  debug "from_xml: $media_id\n";
  
  my $file = $href->{videoInfo}->{title};
  debug "title is: $file\n";
  
  my $release_url = $href->{releaseURL};
  debug "release_url is: $release_url\n";

  unless ($release_url =~ m[^https?://]) {
    debug "encrypted release url: $release_url\n";
    my ($type, $iv, $ciphertext) = split '\$', $release_url, 3;
    $release_url = undef;

    # From http://www-tc.pbs.org/video/media/swf/PBSPlayer.swf
    my $key = 'RPz~i4p*FQmx>t76';

    my $cipher = Crypt::Rijndael->new($key, Crypt::Rijndael->MODE_CBC);
    $iv = pack 'H*', $iv if 32 == length $iv;
    $cipher->set_iv($iv);

    $release_url = $cipher->decrypt(decode_base64($ciphertext));
    $release_url =~ s/\s+$//;
  }
  debug "unencrypted release url: $release_url\n";

  $browser->prohibit_redirects;
  $browser->get($release_url);
  debug "retrieved release_url: $release_url\n";

  my $rtmp_url = $browser->res->header('location')
    || from_xml($browser->content)->{choice}{url}
    || die "Couldn't find stream url\n";
  $rtmp_url =~ s/<break>//;
  debug "rtmp_url: $rtmp_url\n";
  
  my $playpath;
  my $filetype;
  ($playpath, $filetype) = $rtmp_url =~ m[/(([^/:]*):videos.*$)];
  debug "playpath: $playpath\n";
  debug "file type: $filetype\n";

  if(!$file) {
    ($file) = $rtmp_url =~ m{([^/\?]+)$};
  }

  return {
    rtmp    => $rtmp_url,
    playpath => $playpath,
    flashVer => 'LNX 11,2,202,481',
    flv     => title_to_filename($file, $filetype),
  };
}

1;
