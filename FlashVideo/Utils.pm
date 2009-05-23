# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Utils;

use strict;
use base 'Exporter';
use HTML::Entities;
use HTML::TokeParser;
use Encode;

use constant FP_KEY => "Genuine Adobe Flash Player 001";

our @EXPORT = qw(extract_title extract_info title_to_filename get_video_filename
  debug info error swfhash);

sub extract_title {
  my($browser) = @_;
  return extract_info($browser)->{title};
}

sub extract_info {
  my($browser) = @_;
  my($title, $meta_title);

  my $p = HTML::TokeParser->new(\$browser->content);
  while(my $token = $p->get_tag("title", "meta")) {
    my($tag, $attr) = @$token;

    if($tag eq 'meta' && $attr->{name} =~ /title/i) {
      $meta_title = $attr->{content};
    } elsif($tag eq 'title') {
      $title = $p->get_trimmed_text;
    }
  }

  return {
    title => $title, 
    meta_title => $meta_title,
  };
}

sub swfhash {
  my($browser, $url) = @_;

  die "Must have Compress::Zlib and Digest::SHA for this RTMP download\n"
      unless eval {
        require Compress::Zlib;
        require Digest::SHA;
      };

  $browser->get($url);

  my $data = "F" . substr($browser->content, 1, 7)
                 . Compress::Zlib::uncompress(substr $browser->content, 8);

  return
    swfsize => length $data,
    swfhash => Digest::SHA::hmac_sha256_hex($data, FP_KEY),
    swfUrl  => $url;
}

sub title_to_filename {
  my($title, $type) = @_;
  $type ||= "flv";

  # Extract the extension if we're passed a URL.
  $type = $1 if $type =~ /\.(\w+)$/;

  # We want \w below to match non-ASCII characters.
  utf8::upgrade($title);

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
 
  # If we have nothing then return a filestamped filename.
  return get_video_filename($type) unless $title;

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
