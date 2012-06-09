# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Divxstage;

use strict;
use FlashVideo::Utils;
use URI;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  #Extract the file and filekey variables from the flash variable in the HTML
  my ($file) = ($browser->content =~ /flashvars.file\s*=\s*"([a-f0-9]+)"/);
  my ($filekey) = ($browser->content =~ /flashvars.filekey\s*=\s*"([.\-a-f0-9]+)"/);
  
  #cleanest title source is the page title
  my ($filename) = title_to_filename(extract_title($browser));
  $filename =~ s/_-_DivxStage//i;
  
  #Construct a request to the player.api PHP interface, which returns the actual location of the file
  my %query_params = (
    'codes'=>'1',
    'file'=>$file,
    'key'=>$filekey,
    'pass'=>'undefined',
    'user'=>'undefined',);
  
  info "Sending query to DivxStage Player API.";
  
  my $uri = URI->new( "http://www.divxstage.eu/api/player.api.php" );
  $uri->query_form(%query_params);
  
  #parse the url and title out of the response
  my $contents = $browser->get($uri)->content;
  my ($url) = ($contents =~ /url=(.*?)&/);

  die "Couldn't find video URL from the player API." unless $url;
  
  info "Got the real video URL: ".$url;
  # use the API-given title if we need
  $filename ||= ($contents =~ /title=(.*?)&/)[0]; #probably the most reliable source of title
  #fallback to a default name
  $filename ||= get_video_filename();

  return $url, $filename;
}

1;
