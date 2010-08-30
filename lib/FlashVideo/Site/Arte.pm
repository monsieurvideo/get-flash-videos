# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Arte;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;
  my ($lang, $xmlurl1, $xmlurl2, $filename, $videourl, $hash, $playerurl);

  debug "Arte::find_video called, embed_url = \"$embed_url\"\n";

  my $pageurl = $browser->uri() . "";
  if($pageurl =~ /videos\.arte\.tv\/(..)\//) {
    $lang = $1;
  } else {
    die "Unable to find language in original URL \"$pageurl\"\n";
  }

  if($browser->content =~ /videorefFileUrl = "(.*)";/) {
    $xmlurl1 = $1;
    debug "found videorefFileUrl \"$xmlurl1\"\n";
    ($filename = $xmlurl1) =~ s/-.*$//;
    $filename =~ s/^.*\///g;
    $filename = title_to_filename($filename);
  } else {
    die "Unable to find 'videorefFileUrl' in page\n";
  }

  if($browser->content =~ /<param name="movie" value="(http:\/\/videos\.arte\.tv\/[^\?]+)\?/) {
    $playerurl = $1;
    debug "found playerurl \"$playerurl\"\n";
  }

  $browser->get($xmlurl1);

  if($browser->content =~ /<video lang="$lang" ref="(.*)"\/>/) {
    $xmlurl2 = $1;
    debug "found <video ref=\"$xmlurl2\">\n";
  } else {
    die "Unable to find <video ref...> in XML $xmlurl1\n";
  }

  $browser->get($xmlurl2);

  if($browser->content =~ /<url quality="sd">([^<]+)<\/url>/) {
    $videourl = { rtmp => $1,
		flv => $filename};
    if(defined $playerurl) {
      $videourl->{swfVfy} = $playerurl;
    }
  } else {
    die "Unable to find <url ...> in XML $xmlurl2\n";
  }

  return $videourl, $filename;
}

1;
