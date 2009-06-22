# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Redtube;

use strict;
use FlashVideo::Utils;
use List::Util qw(sum);

my @map = qw(R 1 5 3 4 2 O 7 K 9 H B C D X F G A I J 8 L M Z 6 P Q 0 S T U V W E Y N);

sub find_video {
  my($self, $browser, $embed_url) = @_;

  my($title) = $browser->content =~ /<h1[^>]*>([^<]+)</;

  my($id) = $embed_url =~ m!/(\d+)!;
  die "Could not find ID" unless $id;

  my $split = sprintf "%0.7d", int $id / 1000;
  $id = sprintf "%0.7d", $id;
  my @id = split //, $id;

  my $i = 0;
  my $s1 = sum(split //, sum(map { $i++; $_ * $i } @id));
  my @s = split //, sprintf "%0.2d", $s1;

  my $file = join "", map { $_->[1]
    ? $map[ord($id[$_->[0]]) - 48 + $s1 + $_->[1]]
    : $s[$_->[0]]
  } [3, 3], [1], [0, 2], [2, 1], [5, 6], [1, 5], [0], [4, 7], [6, 4];

  return "http://dl.redtube.com/_videos_t4vn23s9jc5498tgj49icfj4678/$split/$file.flv",
    title_to_filename($title);
}

1;
