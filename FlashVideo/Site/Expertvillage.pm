# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Expertvillage;

use strict;
use FlashVideo::Utils;
use URI::Escape;

sub find_video {
  my ($self, $browser) = @_;

  my($fn) = $browser->content =~ /SWFObject\(['"][^'"]+flv=([^'"]+)/;
  my $embedvars = uri_unescape($browser->content =~ /embedvars['"],\s*['"]([^'"]+)/);
  die "Unable to find video info" unless $fn and $embedvars;

  my($title) = $browser->content =~ m{<h1[^>]*>(.*)</h1>}s;
  my $filename = title_to_filename($title);

  $browser->get("$embedvars?fn=$fn");
  die "Unable to get emebdding info" if $browser->response->is_error;

  my $url = uri_unescape($browser->content =~ /source=([^&]+)/);
  die "Unable to find video URL" unless $url;

  return $url, $filename;
}

1;
