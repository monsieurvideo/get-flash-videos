#!perl
use strict;
no warnings;
use lib qw(..);
use Test::More;
use FlashVideo::Site::Googlevideosearch;

{
  my $mech = FlashVideo::Mechanize->new;
  $mech->get("http://www.google.com");
  plan skip_all => "We don't appear to have an internet connection" if $mech->response->is_error;
}

plan tests => 2;

my @results = FlashVideo::Site::Googlevideosearch->search('Iron Man trailer');

ok(@results > 1, "Results returned");

# Check to see if the results look sane
my $sane_result_count = 0;

foreach my $result (@results) {
  if ((ref($result) eq 'HASH') and
      $result->{name} and
      $result->{url} =~ m'^https?://') {
    $sane_result_count++;
  }
}

ok($sane_result_count == @results, "Results look sane");
