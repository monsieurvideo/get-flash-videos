#!perl

use strict;
use lib qw(..);
use Test::More;
use FlashVideo::Utils;
use URI;

my @media_file_extensions = qw(flv mp4 mov wmv avi m4v);

my @test_data = (
  {
     title             => 'Snakes on a plane',
     expected_filename => 'Snakes_on_a_plane.flv',
     test_name         => 'Default .flv extension used.',
  },
  {
     title             => 'Consecutive  spaces',
     expected_filename => 'Consecutive_spaces.flv',
     test_name         => 'Consecutive spaces collapsed to single space.',
  },

  # Extracting file type from URL
  (map {
    {
       title             => 'Snakes on a plane',
       expected_filename => "Snakes_on_a_plane.$_",
       test_name         => "File type ($_) detected from URL.",
       type              => "http://example.com/snakes_on_a_plane.$_",
    },
  } @media_file_extensions),

  # Extracting file type from title 
  (map {
    {
       title             => "Snakes on a plane.$_",
       expected_filename => "Snakes_on_a_plane.$_",
       test_name         => "File type ($_) detected from title.",
    },
  } @media_file_extensions),

  
  {
     title             => ' Ugly ',
     expected_filename => 'Ugly.flv',
     test_name         => 'Spaces at start and end of filename removed.',
  },
  {
     title             => 'Invalid /" chars',
     expected_filename => 'Invalid____chars.flv',
     test_name         => 'Invalid chars removed.',
  },
  {
     title             => 'Test subtitles file',
     type              => 'srt',
     expected_filename => 'Test_subtitles_file.srt',
     test_name         => 'Manually-supplied type/extension works (subtitle support).',
  },
);

plan tests => scalar @test_data;

foreach my $test (@test_data) {
  my $filename = title_to_filename(
    $test->{title},
    $test->{type},
  );

  is($filename, $test->{expected_filename}, $test->{test_name}); 
}
