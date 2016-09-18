# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Ustream;

use strict;
use FlashVideo::Utils;
use FlashVideo::JSON;
use HTML::Entities qw(decode_entities);
use Text::Balanced qw (extract_codeblock);

=pod

Programs that work:
    - http://www.ustream.tv/recorded/90549242
    - http://www.ustream.tv/recorded/89581110
    - http://www.ustream.tv/recorded/49307509
    - http://www.ustream.tv/recorded/429648
    - http://www.ustream.tv/recorded/90985738
    - http://www.ustream.tv/recorded/59501326

Programs that don't work yet: (may require a ustream site login capability)
    - http://www.ustream.tv/recorded/90800134
    - 

TODO:
    - find out why http://www.ustream.tv/recorded/90800134 does not work

=cut

our $VERSION = '0.02';
sub Version() { $VERSION };

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  # ustream returns the video metadata as a javascript variable
  # extract the embedded javascript and extract the ustream.vars.videoData variable
  my @scriptags =  $browser->content() =~/<script[^>]*>(.+?)<\/script>/sig;
  my $script;
  my $usdata;
  local $/ = "\r\n";
  foreach $script (@scriptags)
  {
     if ($script =~ /ustream.vars.videoData/si) {
       # find the beginning of the video metadata block
       ($script) = $script =~ /ustream.vars.videoData *= *(.*)/s;
       # extract the metadata block
       # use Test::Balanced::extract_codeblock as the regex parser cannot handle
       # nested parentheses, quote and escaped characters.
       ($usdata) = extract_codeblock($script);
       # fix up the HTML entities
       $usdata = decode_entities($usdata);
       debug $usdata;
       last;
     }
  }
# Parse the json structure
  my $result = from_json($usdata);
  debug Data::Dumper::Dumper($result);
  die "Could not extract video metadata.\n   Video may not be available.\n"
     unless ref($result) eq "HASH";
  
  # Get the video's title and urs source
  my $title = $result->{title};
  die "Could not extract video title" unless $title;
  debug "title is: $title\n";
  
  my $flv_url = $result->{media_urls}->{flv};
  die "Could not extract video url" unless $flv_url;
  debug "url extracted\n";
  
  $browser->allow_redirects;
  
  return $flv_url, title_to_filename($title);
}

1;
