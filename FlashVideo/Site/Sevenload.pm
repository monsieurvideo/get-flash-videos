# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Sevenload;

use strict;
use FlashVideo::Utils;
use HTML::Entities;
use URI::Escape;

sub find_video {
  my ($self, $browser) = @_;

  my $has_xml_simple = eval { require XML::Simple };
  if(!$has_xml_simple) {
    die "Must have XML::Simple installed to download Sevenload videos";
  }

  die "Could not find configPath" unless $browser->content =~ /configPath=([^"']+)/;
  my $configpath = uri_unescape(decode_entities($1));
  $browser->get($configpath);

  my $config = eval { XML::Simple::XMLin($browser->content) };
  
  if($@) {
    die "Error parsing config XML: $@";
  }

  my($title, $location);

  eval {
    my $item = $config->{playlists}->{playlist}->{items}->{item};
    $title = title_to_filename($item->{title});

    my $streams = $item->{videos}->{video}->{streams}->{stream};
    $streams = [ $streams ] unless ref $streams eq 'ARRAY';

    # Attempt to get the highest definition content
    $location = (sort { $b->{width} <=> $a->{width} } @$streams)[0]
      ->{locations}->{location}->{content};
  };

  return $location, $title if $location;

  die "Unable to get stream location" . ($@ ? ": $@" : "");
}

1;
