# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Amazon;

use strict;

use Encode;
use FlashVideo::Utils;
use URI::Escape;

my $playlist_url_template = 'http://%s/gp/mpd/getplaylist-v2/%s/%s';

sub find_video {
  my ($self, $browser) = @_;

  # Amazon's various sites like amazon.com, amazon.co.uk and so on need
  # special handling.
  my $amazon_host = $browser->uri()->host();

  # Not all pages have xmlUrl
  if ($browser->content =~ /swfParams\.xmlUrl = ["'](http:.*?)["']/) {
    debug "Getting Amazon URL direct URL $1";
    $browser->get($1);
  }
  else {
    # Get the video ID (aka "media object ID") and session ID
    my ($video_id, $session_id);
    
    if ($browser->content =~
      /swfParams\.mediaObjectId = ["'](.*?)["']/) {
      $video_id = $1;
    }
    else {
      die "Couldn't find video ID / media object ID in Amazon page";
    }

    if ($browser->content =~
      /swfParams\.sessionId = ["'](.*?)["']/) {
      $session_id = $1;
    }
    else {
      die "Couldn't find session ID in Amazon page";
    }

    my $playlist_url =
      sprintf($playlist_url_template, $amazon_host, $video_id, $session_id);

    $browser->get($playlist_url);
  }

  my ($title, @video_urls) = parse_smil_like_xml($browser->content);

  my $filename = title_to_filename($title);

  # TODO - handle quality preference. Return best quality for now.
  return $video_urls[0], $filename;
}

# This doesn't seem to be standard SMIL, hence the function name. Not
# putting this into Utils until we see other sites using this same
# pseudoformat.
sub parse_smil_like_xml {
  my $smil = shift;

  die "Must have XML::Simple installed to parse SMIL"
    unless eval { require XML::Simple };

  my $parsed_smil = eval { XML::Simple::XMLin($smil) };

  if ($@) {
    die "Couldn't parse SMIL: $@";
  }

  # SMIL structure is like:
  # videoObject
  #    |
  #    ----> description
  #    ----> title 
  #    ----> body
  #           |
  #           ----> switch
  #                   |
  #                   ----> video
  #                           |
  #                           ----> src
  #                           ----> system-bitrate
  #                           ----> dur

  my $title;

  # But Amazon.jp uses a different format
  my $video_ref = $parsed_smil->{videoObject}->{smil}->{body}->{switch}->{video}; 
  if (ref($video_ref) ne 'ARRAY') {
    # Get the 0th video
    my $id;

    my %videos = %{ $parsed_smil->{videoObject} };

    foreach my $video (keys %videos) {
      next unless ref $videos{$video};

      if ($videos{$video}->{index} == 0) {
        $id = $video;
        $title = $videos{$video}->{title};
        last;
      }
    }

    $video_ref = $parsed_smil->{videoObject}->{$id}->{smil}->{body}->{switch}->{video}; 
  }

  my @different_quality_videos = map { $_->{src} }
                                 sort { $b->{'system-bitrate'} <=> $a->{'system-bitrate'} }
                                 @$video_ref;

  # Sometimes, for no valid reason, the title is URL escaped.
  $title ||= $parsed_smil->{videoObject}->{title};

  if ($title !~ /\s/) {
    # No spaces, so try to unescape
    $title = uri_unescape($title);
  }

  return ($title, @different_quality_videos);
}

1;
