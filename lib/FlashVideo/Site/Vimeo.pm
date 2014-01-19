# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Vimeo;

use strict;
use warnings;
use FlashVideo::Utils;
use FlashVideo::JSON;

our $VERSION = '0.02';
sub Version() { $VERSION; }

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;

  my $id;

  if ($browser->response->is_redirect) {
    my $relurl = $browser->response->header('Location');
    info "Relocated to $relurl";
    $browser->get($relurl);
  }

  my $page_url = $browser->uri->as_string;

  if ($embed_url =~ /clip_id=(\d+)/) {
    $id = $1;
  } elsif ($embed_url =~ m!/(\d+)!) {
    $id = $1;
  }
  die "No ID found\n" unless $id;

  # this JSON response will contain title and video URLs
  my $info_url = "http://player.vimeo.com/v2/video/$id/config";
  $browser->get($info_url);
  my $video_data = from_json($browser->content);
  my $title = $video_data->{video}{title};
  my $filename = title_to_filename($title, "mp4");

  my @formats = map {
          { resolution => [$_->{width}, $_->{height}], url => $_->{url} }
      } values $video_data->{request}{files}{h264};

  my $preferred_quality = $prefs->quality->choose(@formats);

  return $preferred_quality->{url}, $filename;
}

1;
