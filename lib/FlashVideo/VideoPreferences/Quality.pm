# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::VideoPreferences::Quality;

use strict;

my %format_map = (
  "240p"  => [320,  240,  "low"],
  "240w"  => [427,  240,  "low"],
  "480p"  => [640,  480,  "medium"],
  "480w"  => [854,  480,  "medium"],
  "576p"  => [720,  576,  "medium"],
  "720p"  => [1280, 720,  "high"],
  "1080p" => [1920, 1080, "high"],
);

sub new {
  my($class, $quality) = @_;

  return bless \$quality, $class;
}

sub name {
  my($self) = @_;
  return $$self;
}

sub choose {
  my($self, @available) = @_;

  # To make it easier we take the total number of pixels in a resolution, this
  # may be a bit confusing if someone prefers a widescreen version and we don't
  # choose it, however they can always specify the precise format in that case.
  
  # TODO: If we have a video at a higher res than 1080p we won't choose it,
  # maybe need to extend high (or add a very-high?).

  my $max_preferred_res = $self->quality_to_resolution($self->name);
  my $max_preferred_size = $max_preferred_res->[0] * $max_preferred_res->[1];

  my @sorted = 
    sort { $a->[0] <=> $b->[0] }
    map { my $r = $_->{resolution}; $r = $r->[0] * $r->[1]; [$r, $_] } @available;

  if(my @at_or_under_preferred = grep { $_->[0] <= $max_preferred_size } @sorted) {
    # Max under preferred size
    return $at_or_under_preferred[-1]->[1];
  } else {
    # Min over preferred size
    return $sorted[0]->[1];
  }
}

sub format_to_resolution {
  my($self, $name) = @_;
  $name .= "p" if $name !~ /[a-z]$/i;

  if(my $resolution = $format_map{lc $name}) {
    return $resolution;
  } elsif(my $num = ($name =~ /(\d+)/)[0]) {
    # Don't know about this, we'll return the number given as the size, in theory the
    # height should be correct, which means if anything we'll be slightly under
    # on the resolution.
    my $resolution = [($num) x 2];
    return [@$resolution, $self->resolution_to_quality($resolution)];
  }

  die "Unknown format '$name'";
}

sub quality_to_resolution {
  my($self, $quality) = @_;

  # Allow specifying an actual resolution
  if($quality =~ /^(\d+)x(\d+)$/) {
    my $resolution = [$1, $2];
    return [@$resolution, $self->resolution_to_quality($resolution)];

  # See if they specified a named format
  } elsif(my $resolution = eval { $self->format_to_resolution($quality) }) {
    return $resolution;

  } else {
    # Search backwards until we find the name they specified.
    for my $r(sort { ($b->[0]*$b->[1]) <=> ($a->[0]*$a->[1]) }
        values %format_map) {
      if($r->[2] eq lc $quality) {
        return $r;
      }
    }
  }

  die "Unknown quality '$quality'";
}

sub resolution_to_quality {
  my($self, $resolution) = @_;

  my $quality = "high";

  for my $r(sort { ($b->[0]*$b->[1]) <=> ($a->[0]*$a->[1]) }
      values %format_map) {
    $quality = $r->[2] if $r->[0] >= $resolution->[0];
  }

  return $quality;
}

1;
