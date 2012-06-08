# Part of get-flash-videos. See get_flash_videos for copyright.

#This package handles sites such as GorillaVid.in, DaClips.in and 
# MovPod.in
package FlashVideo::Site::Gorillavid;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  #the form that needs to be submitted to get the video page is the 
  #second one (first is a search)
  $browser->form_number('2');
  
  #extract the filename from the form
  my $filename = $browser->value( 'fname' );
  
  info 'Submitting form to get real video page';
  $browser->submit(); #submit to get the real page
  
  my ($url) = ($browser->content =~ /file: *"(https?:\/\/.*?)"/);
  
  #derive extension from the filename, if there is one
  my ($ext) =  ($url =~ /(\.[a-z0-9]{2,4})$/); 
  
  return $url, $filename.$ext;
}

sub can_handle {
  my($self, $browser, $url) = @_;

  return 1 if $url && URI->new($url)->host =~ /(gorillavid|daclips|movpod)\.in$/;
}

1;
