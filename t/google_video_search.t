#!perl
use strict;
no warnings;
use lib qw(..);
use Test::More tests => 2;
use FlashVideo::Site::Googlevideosearch;

my @results = FlashVideo::Site::Googlevideosearch->search('Iron Man trailer');

ok(@results > 1, "Results returned");

# Check to see if the results look sane
my $sane_result_count = 0;

foreach my $result (@results) {
  if ((ref($result) eq 'HASH') and
      $result->{name} and
      $result->{url} =~ m'^http://') {
    $sane_result_count++;
  }
}

ok($sane_result_count == @results, "Results look sane");
