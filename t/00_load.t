#!perl

use warnings;
use strict;
use Test::More tests => 20;

BEGIN {
    chdir 't' if -d 't';
    push @INC, '../lib';

    my @classes = qw(
        Compress::Zlib
        FlashVideo::Downloader
        FlashVideo::Generic
        FlashVideo::Mechanize
        FlashVideo::RTMPDownloader
        FlashVideo::Search
        FlashVideo::Site
        FlashVideo::URLFinder
        FlashVideo::Utils
        FlashVideo::VideoPreferences
        HTML::Entities
        HTML::TokeParser
        HTTP::Config
        HTTP::Cookies
        HTTP::Request::Common
        LWP::Protocol::http
        Tie::IxHash
        URI
        WWW::Mechanize
        XML::Simple
    );

    foreach my $class (@classes) {
        use_ok $class or BAIL_OUT("Could not load $class");
    }
}
