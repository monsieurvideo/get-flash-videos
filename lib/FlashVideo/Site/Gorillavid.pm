# Part of get-flash-videos. See get_flash_videos for copyright.

#This package handles sites such as GorillaVid.in, DaClips.in and 
# MovPod.in
package FlashVideo::Site::Gorillavid;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;
  my $filename;

  for my $form ($browser->forms) {
    if ($form->find_input('#btn_download')){
      $filename = $form->value('fname'); #extract the filename from the form
      
      info 'Submitting form to get real video page.';
      $browser->request($form->click()); #submit to get the real page
    }
  }
  
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
