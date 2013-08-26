# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Nhk;

use strict;
use FlashVideo::Utils;
use URI::Escape;

our $VERSION = '0.01';
sub Version() {$VERSION;}

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  # Grab the file from the page..
  my $url = ($browser->content =~ /<div id="news_video">(.+?)</)[0];
  die "Unable to extract url" unless $url;

  # Extract filename from page and format

  # title_to_filename() can't extract extension from URLs like
  # foo.flv?stuff - should probably change, but for now don't bother
  # passing in the URL. (Will default to .flv)
    
  return { rtmp => "rtmp://flv.nhk.or.jp/ondemand/flv/news/".$url,
  	flv => $url};
}

1;
