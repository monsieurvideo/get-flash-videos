# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::GoogleVideoSearch;

use strict;

use FlashVideo::Mechanize;
use FlashVideo::URLFinder;
use FlashVideo::Utils;

sub search {
  my $search = shift;

  my $browser = FlashVideo::URLFinder::get_browser();
  
  $browser->get('http://video.google.com/');

  $browser->submit_form(
    with_fields => {
      q => $search,
    }
  );

  return unless $browser->success;

  my @links = map  { 
                     chomp(my $name = $_->text);
                     { name => $name, url => $_->url_abs->as_string }
              }
              grep { $_->attrs()->{onclick} =~ /return resultClick/ }
              $browser->find_all_links(text_regex => qr/.+/);

  return @links;
}

1;
