# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Arte;

use strict;
use FlashVideo::Utils;
use FlashVideo::JSON;

our $VERSION = '0.02';
sub Version { $VERSION; }

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;
  my ($jsonurl, $filename, $title, $videourl, $quality);

  debug "Arte::find_video called, embed_url = \"$embed_url\"\n";

  if($browser->content =~ /arte_vp_url=['"](.*)['"]/) {
    $jsonurl = $1;
    debug "found arte_vp_url \"$jsonurl\"\n";
    ($filename = $jsonurl) =~ s/-.*$//;
    $title = extract_title($browser);
  } else {
    die "Unable to find 'arte_vp_url' in page\n";
  }

  $browser->get($jsonurl);

  $quality = {high => 'SQ', medium => 'MQ', low => 'LQ'}->{$prefs->{quality}};

  my $result = from_json($browser->content());
  my $protocol = "";

  if (defined ($result->{videoJsonPlayer}->{VSR}->{'RTMP_'.$quality.'_1'})) {
    my $video_json = $result->{videoJsonPlayer}->{VSR}->{'RTMP_'.$quality.'_1'};
    $filename = title_to_filename($title, 'flv');

    $videourl = {
      rtmp     => $video_json->{streamer},
      playpath => 'mp4:'.$video_json->{url},
      flv      => $filename,
    };

    return $videourl, $filename;
  } elsif (defined ($result->{videoJsonPlayer}->{VSR}->{'HTTP_MP4_'.$quality.'_1'})) {
    my $video_json = $result->{videoJsonPlayer}->{VSR}->{'HTTP_MP4_'.$quality.'_1'};
    $filename = title_to_filename($title, 'mp4');

    return $video_json->{url}, $filename;
  } elsif (defined ($result->{videoJsonPlayer}->{VSR}->{'HTTP_'.$quality.'_1'})) {
    my $video_json = $result->{videoJsonPlayer}->{VSR}->{'HTTP_'.$quality.'_1'};
    $filename = title_to_filename($title, 'mp4');

    return $video_json->{url}, $filename;
  } else {
    die "Unable to figure out transport protocol in page\n";
  }

}

1;
