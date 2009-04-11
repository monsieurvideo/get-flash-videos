# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Xnxx;

use strict;
use FlashVideo::Utils;

sub find_video {
    my ($self, $browser, $url) = @_;

    # Grab the file from the page..
    my $file = ($browser->content =~ /flv_url=(.+?)&/)[0];
        die "Unable to extract file" unless $file;
    
    my $suffix = ($file =~ /http.+\.(.+)$/)[0];

    my $filename = 'default';

    if ($browser->content =~ /video\d+\/(.+)\|\|/) {
        $filename = $1 . '.' . $suffix;
        $filename =~ s/%\d\d//g;
        $filename =~ s/__/-/g;
        $filename =~ s/_/-/g;
    }
      die "Unable to name file" if $filename =~ /default/;
    
    return $file, $filename;
}

1;
