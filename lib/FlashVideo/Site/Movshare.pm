# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Movshare;

use strict;
use FlashVideo::Utils;
use URI;

our $VERSION = '0.01';
sub Version() {
    $VERSION;
}

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  #Extract the file and filekey variables from the flash variable in the HTML
  my $file = ($browser->content =~ /flashvars.file\s*=\s*"(.+?)"/)[0];
  my $filekey = ($browser->content =~ /flashvars.filekey\s*=\s*"([.\-a-f0-9]+)"/)[0];

  #Construct a request to the player.api PHP interface, which returns the actual location of the file
  my %query_params = (
    'file'=>$file,
    'key'=>$filekey,);

  info "Sending query to API...";

  my $uri = URI->new( "http://www.movshare.net/api/player.api.php" );
  $uri->query_form(%query_params);

  # Appear to be a Real Web Browser. Necessary to convince Movshare to yield
  # real results.
  $browser->add_header("User-Agent" => "Mozilla/6.9");

  #parse the url and title out of the response
  my $contents = $browser->get($uri)->decoded_content;
  debug "API reply: $contents";
  my ($url) = ($contents =~ /url=(.*?)&/);

  die "Couldn't find video URL from the player API!" unless $url;

  debug "Got the real video URL: ".$url;
  # Use the title from the API; it's pretty reliable.
  my $filename = ($contents =~ /title=(.*?)&/)[0];
  #fallback to a default name
  $filename ||= get_video_filename();

  return $url, $filename;
}

sub can_handle {
  my ($self, $browser, $url) = @_;

  return $url =~ m{movshare\.net};
}

1;
