# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Seesaw;

use strict;
use FlashVideo::Utils;
use HTML::Entities qw(decode_entities);

my @res = (
  { name => "lowResUrl",  resolution => [ 512, 288 ] },
  { name => "stdResUrl",  resolution => [ 672, 378 ] },
  { name => "highResUrl", resolution => [ 1024, 576 ] }
);

sub find_video {
  my ($self, $browser, $page_url, $prefs) = @_;

  my $player_info = ($browser->content =~ m{player\.init\(.*"(/\w+/\d+)})[0];

  # Grab title and normalise
  my @titles = map { decode_entities($_) } $browser->content =~ m{<h3\s+id="title(?:Ext)?"[^>]*>(.*?)</h3>}ig;

  if($titles[1] =~ /Series (\d+)/) {
    $titles[1] = sprintf "S%02d", $1;
    if($titles[2] =~ s/Episode (\d+):?//) {
      $titles[1] .= sprintf "E%02d", $1;
    }
  }

  my $title = join " - ", grep length, @titles;

  # Grab player info
  $browser->get($player_info);

  my @urls;
  for my $res(@res) {
    if($browser->content =~ /$res->{name}":\["([^"]+)/) {
      push @urls, { %$res, url => $1 };
    }
  }

  die "No video URLs found" unless @urls;

  my $rtmp = $prefs->quality->choose(@urls);

  my($app, $playpath, $query) = $rtmp->{url} =~ m{^\w+://[^/]+/(\w+/\w+)(/[^?]+)(\?.*)};
  my $prefix = "mp4";
  $prefix = "flv" if $playpath =~ /\.flv$/;

  return {
    flv      => title_to_filename($title),
    rtmp     => $rtmp->{url},
    app      => $app,
    playpath => "$prefix:$playpath$query"
  }
}

1;
