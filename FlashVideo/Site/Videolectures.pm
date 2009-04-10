# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Videolectures;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser) = @_;

  my $author = ($browser->content =~ /author:\s*<a [^>]+>([^<]+)/s)[0];
  my $title  = ($browser->content =~ /<h2>([^<]+)/)[0];

  my $streamer = ($browser->content =~ /streamer:\s*["']([^"']+)/)[0];
  my $playpath = ($browser->content =~ /file:\s*["']([^"']+)/)[0];
  $playpath =~ s/\.flv$//;

  my $data = {
    app      => (split m{/}, $streamer)[-1],
    rtmp     => $streamer,
    playpath => $playpath,
    flv      => title_to_filename("$author - $title")
  };
    
  return $data;
}

1;
