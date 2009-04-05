#!/usr/bin/perl
# http://board.flashkit.com/board/archive/index.php/t-283660.html
use strict;
use Compress::Zlib;

my $file = shift;
-f $file or die "Usage: $0 file > output\n";

open my $fh, "<", $file or die $!;
binmode $fh;
my $body;
read $fh, $body, -s $file;

die "Doesn't look like compressed flash to me..\n" unless 'C' eq substr $body, 0, 1;
substr($body, 0, 1) = "F";

print substr $body, 0, 8;
print uncompress(substr $body, 8);
