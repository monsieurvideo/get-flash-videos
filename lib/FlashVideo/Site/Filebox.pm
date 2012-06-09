# Part of get-flash-videos. See get_flash_videos for copyright.

package FlashVideo::Site::Filebox;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;
  
  my $pause = 5; #if we don't pause, we don't get the proper video page
  info 'Pausing for '.$pause.' seconds (or the server won\'t respond)...';
  sleep($pause);
  
  my $btn_id = 'btn_download'; #the ID of the button to submit the form
  for my $form ($browser->forms) {
    if ($form->find_input('#'.$btn_id)){     
      info 'Submitting form to get real video page.';
      $browser->request($form->click('#'.$btn_id)); #submit to get the real page
    }
  }
  
  my ($filename) = ($browser->content =~ /product_file_name=(.*?)[&'"]/);
  my ($url) = ($browser->content =~ /product_download_url=(.*?)[&'"]/);
  
  return $url, $filename;
}

1;
