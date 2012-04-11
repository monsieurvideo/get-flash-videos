# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Nasa;

use strict;
use FlashVideo::Utils;
use FlashVideo::JSON;

sub find_video {
  my ($self, $browser, $embed_url) = @_;
  
  # setup and get javascript that identifies the video server and video path
  my $uri = $browser->uri();
  my $path = $uri->path();
  $path =~ s/index\.html//;               # strip the index.htm at the end of the path.
  $path = $path . "vmixVideoLanding2.js"; # specify the javascript src
  
  # extract the site's action and media_id from the url
  debug "Nasa videogallery query is " . $uri->query();
  my ($media_id) = $uri->query() =~ m/media_id=(\d+)/;
  
  # Site support for NASA videogallery specifying video by media_id (at this time).
  die "Nasa support requires 'media_id=nnnnnnnn' in the query" unless $media_id;
  
  $uri->path($path);                      # Change path to javascript src
  $uri->query(undef());                   # Remove the query

  info "Downloading video source instructions at " . $uri;
  $browser->get($uri);
  
  die "Could not locate video source" unless $browser->success();
  
  my $videojs = $browser->content();      # content is javascript
  
  # extract the video source host
  my ($api_url_host) = $browser->content() =~ m{var +api_url *= *'([^']*)' *;};
  die "Could not extract video server" unless $api_url_host;
  
  # extract atoken required for JSON request
  my ($atoken) = $browser->content() =~ m{var +atoken *= *'([^']*)' *;};

  # format query to get video details in JSON  
  my $query = 'http://' . $api_url_host . '/apis/media.php?action=getMedia&export=JSONP&media_id=' . $media_id . '&atoken=' . $atoken . '&callback=loadCurrentVideo1';
  
  info "Downloading video details from http://" . $api_url_host;
  $browser->get($query);
  die "Could not get video details" unless $browser->success();
  
  # Content is JSON fomatted
  my $result = from_json($browser->content());
  
  # Get the video's url
  my $url = $result->{url};
  die "Could not extract video url" unless $url;
  # Hack: not sure why/where the "core" in the url is mutated to "core-dl" so just hacking it here
  $url =~ s/\/core\//\/core-dl\//;
  
  # Get the video's title from the JSON
  my $filename = $result->{title};
  $filename = title_to_filename($filename, "mp4");

  return $url, $filename;
}

1;
