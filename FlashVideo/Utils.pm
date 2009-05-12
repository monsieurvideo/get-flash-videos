# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Utils;

use strict;
use base 'Exporter';
use HTML::Entities;

our @EXPORT = qw(title_to_filename get_video_filename debug info error);

sub title_to_filename {
  my($title, $type) = @_;
  $type ||= "flv";

  my $has_extension = $title =~ /\.[a-z0-9]{3,4}$/;

  $title = decode_entities($title);

  # Some sites have double-encoded entities, so handle this
  if ($title =~ /&(?:\w+|#(?:\d+|x[A-F0-9]+));/) {
    # Double-encoded - decode again
    $title = decode_entities($title);
  }

  $title =~ s/\s+/_/g;
  $title =~ s/[^\w\-,()&]/_/g;
  $title =~ s/^_+|_+$//g;   # underscores at the start and end look bad

  $title .= ".$type" unless $has_extension;
  return $title;
}

sub get_video_filename {
  my($type) = @_;
  $type ||= "flv";
  return "video" . get_timestamp_in_iso8601_format() . "." . $type; 
}

sub get_timestamp_in_iso8601_format { 
  use Time::localtime; 
  my $time = localtime; 
  return sprintf("%04d%02d%02d%02d%02d%02d", 
                 $time->year + 1900, $time->mon + 1, 
                 $time->mday, $time->hour, $time->min, $time->sec); 
}

sub debug(@) {
  print STDERR "@_\n" if $::opt{debug};
}

sub info(@) {
  print STDERR "@_\n" unless $::opt{quiet};
}

sub error(@) {
  print STDERR "@_\n";
}

1;
