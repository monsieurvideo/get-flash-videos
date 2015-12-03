# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Pbs;

use strict;
use warnings;
use FlashVideo::Utils;
use FlashVideo::JSON;

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
    - hi-res with PBS Video login ID

=cut

our $VERSION = '0.03';
sub Version() { $VERSION; }

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;

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
  
  # format query to get video details in JSON  
  my $query = 'http://player.pbs.org/videoInfo/' . $media_id . '/?callback=video_info&format=jsonp&type=portal';
  
  info "Downloading video metadata";
  $browser->get($query);
  die "Could not get video metadata" unless $browser->success();
  
  # Content is JSON fomatted
  my $result = from_json($browser->content());
  
  # Get the video's title and urs source
  my $title = $result->{title};
  die "Could not extract video title" unless $title;
  debug "title is: $title\n";
  
  my $urs = $result->{alternate_encoding}->{url};
  die "Could not extract video urs" unless $urs;
  debug "urs extracted\n";
  
  # format another query to get video url in JSON  
  $query = $urs . '?format=json';
  
  info "Downloading video details";
  $browser->get($query);
  die "Could not get video details" unless $browser->success();
  
  # Content is JSON fomatted
  $result = from_json($browser->content());
  
  # Get the video's url source
  my $url = $result->{url};
  die "Could not extract video url" unless $url;
  debug "found PBS video: $media_id url\n";
  
  my ($filetype) = $url =~ m[.*\.([a-zA-Z0-9]+)]x;
  debug "filetype is: $filetype\n";

  return $url, title_to_filename($title, $filetype);
}

1;
