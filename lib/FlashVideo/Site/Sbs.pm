# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Sbs;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;

  my($id) = $browser->content =~ /firstVidId = '([^']*)';/;

  die "No video ID found" unless $id;

  my($baseurl) = $browser->content =~ m{so\.addVariable\("nielsenLaunchURL", *"([^"]*)"\);}s ;
  my($menu) = $browser->content =~ m{loadVideo\('([^']*)', '', [^\)]\);}s ;
  if( !$menu ){ $menu = $baseurl . '/video/menu/inline/id/' . $id; }
  else { $menu = 'http://www.sbs.com.au' . $menu; }
  $menu =~ s/' *\+ *firstVidId *\+ *'/$id/g;

  die "No menu URL found" unless $menu;

  $browser->get($menu);

  my($smil) = $browser->content =~ m{<video *name="[^"]*" *id="[^"]*" *src="([^"]*)">}s ;

  die "no smil" unless $smil;

  $browser->get($smil);

  ($baseurl) = $browser->content =~ m'<meta base="([^"]*)"/>'s;

  die "no baseurl" unless $baseurl;

  my @tmp = $browser->content =~ m'<video src="([^"]*)" system-bitrate="([^"]*)"/>'gs;
  my %tmp = reverse @tmp;
  my $filename;
  my $q = $prefs->{quality};
  if( grep {$_ eq $q || $_ == $q || $_ == ($q * 100000)} keys(%tmp) ){
    $filename = $tmp{$q};
    if(!$filename){
      my @bitrates = grep {$_ == $q || $_ == ($q * 100000)} keys(%tmp);
      $filename = $tmp{$bitrates[0]};
    }
  } else {
    my @filenames = ();
    foreach (sort { $a <=> $b } keys(%tmp) )
      { push @filenames, $tmp{$_}; }
    my $cnt = @filenames;
    my $num = {high => int($cnt/3)*2, medium => int($cnt/3)*1, low => int($cnt/3)*0}->{$q};
    $filename = $filenames[$num];
  }

  die "no filenames" unless $filename;

  if( $baseurl =~ /^rtmp:/ ){
    my($flvname) = $filename =~ m'[^/]*/(.*)'s;
    return {
      rtmp => $baseurl,
      playpath => $filename,
      flv => $flvname
    };
  } else {
    my $url = $baseurl . $filename;
    return $url, $filename;
  }
}

1;
