# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Googlevideosearch;

use strict;
no warnings 'uninitialized';
use FlashVideo::Mechanize;
use URI::Escape;

sub search {
  my($self, $search, $type) = @_;

  my $browser = FlashVideo::Mechanize->new;

  $browser->allow_redirects;
  
  $browser->get('http://video.google.com/videoadvancedsearch');

  $browser->submit_form(
    with_fields => {
      q => $search,
    }
  );

  return unless $browser->success;

  my @links = map  { 
                     chomp(my $name = $_->text);
                     my $url = $_->url_abs->as_string;
                     $url =~ /q=([^&]*)/;
                     $url = uri_unescape($1);
                     { name => $name, url => $url }
              }
              $browser->find_all_links(text_regex => qr/.+/, url_regex => qr/\/url/);

  return @links;
}

1;
