# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Liveleak;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  # Get file embed tag
  my $file_embed_tag;
  if ($browser->content =~ /file_embed_tag(?:%3D|=)(\w+)\W/) {
    $file_embed_tag = $1; 
  }
  else {
    die "Unable to get file_embed_tag";
  }

  $browser->get("http://www.liveleak.com/playlist_new.php?file_embed_tag=$file_embed_tag");

  if (!$browser->success) {
    die "Couldn't download LiveLeak playlist: " . $browser->response->status_line();
  }

  # Response is XML but using XML::Simple is overkill.
  my $video_url;
  if ($browser->content =~ m'<location>(http://.*?)</location>') {
    $video_url = $1;
  }
  else {
    die "Unable to extract LiveLeak video URL";
  }

  # URL might be a redirect
  if (my $redirected_url = $browser->head($video_url)->header('Location')) {
    $video_url = $redirected_url;
  }

  $browser->back();

  # Figure out title
  my $title;
  if ($browser->content =~ m'<h4 id="s_hd">(.*?)</h4>') {
    $title = $1;
  }
  else {
    $title = extract_title($browser);
  }

  return $video_url, title_to_filename($title);
}

1;
