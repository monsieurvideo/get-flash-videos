#!perl
use strict;
use lib qw(..);
use Test::More tests => 3;
use Tie::IxHash;

BEGIN {
  use_ok "FlashVideo::RTMPDownloader";
}

my $r = FlashVideo::RTMPDownloader->new;

# Ensure ordering is consistent.
my %data;
tie %data, "Tie::IxHash",
    verbose => undef, conn => [qw/O:1 NS:foo/], rtmp => "rtmp://blah";

is_deeply([$r->get_command(\%data)],
  [qw{--verbose --conn O:1 --conn NS:foo --rtmp rtmp://blah}]);

is(join(" ", $r->get_command(\%data, 1)),
  "--verbose --conn 'O:1' --conn 'NS:foo' --rtmp 'rtmp://blah'");
