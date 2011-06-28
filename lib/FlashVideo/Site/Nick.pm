# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Nick;

use strict;
use FlashVideo::Utils;
use URI::Escape;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  #/mgid:cms:video:spongebob.com:895944

  my $page_url = $browser->uri->as_string;

  my $title;
  if($browser->content =~ /<span content=["']([\w \.:]+)["'] property=["']media:title["']\/>/) {
    $title = $1;
  } else {
    $title = "nothing";
  }

  my $cmsId;
  if($browser->content =~ /KIDS\.add\("cmsId", "(\d+)"\);/) {
    $cmsId = $1;
  } else {
    die "Couldn't get the cmsId.";
  }

  my $site;
  if($browser->content =~ /KIDS\.add\(["']site["'], ["']([\w\.]+)["']\);/) {
    $site = lc($1);
  } else {
    die "Couldn't get the site.";
  }

  my $type;
  if($browser->content =~ /KIDS\.add\(["']type["'], ["']([a-z]+)["']\);/) {
    $type = $1;
  } else {
    $type = "video";
  }

  my $uri = "mgid:cms:$type:$site:$cmsId";

  $browser->get("http://www.nick.com/dynamo/video/data/mediaGen.jhtml?mgid=$uri");
  my $xml = from_xml($browser->content);
  my $rtmp_url = $xml->{video}->{item}[0]->{rendition}[0]->{src};

  return {
    rtmp => $rtmp_url,
    flv => title_to_filename($title),
    pageUrl => $page_url,
    swfhash($browser, "http://media.nick.com/" . $uri)
  };
}

sub can_handle {
  my($self, $browser) = @_;
  return $browser->content =~ /<script src=["']http:\/\/media.nick.com\/player\/scripts\/mtvn_player_control\.1\.0\.1\.js["']/;
}

1;
