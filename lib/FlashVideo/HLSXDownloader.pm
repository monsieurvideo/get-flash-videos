# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::HLSXDownloader;

use strict;
use warnings;
use base 'FlashVideo::Downloader';
use FlashVideo::Utils;
use FlashVideo::JSON;
use FlashVideo::Mechanize;
use Term::ProgressBar;

my $bitrate_index = {
  high   => 0,
  medium => 1,
  low    => 2
};

sub cleanup_audio {
  my ($in_file, $out_file) = @_;
  my @args = {};

  # Look for executable (ffmpeg or avconv)
  if (!is_program_on_path("ffmpeg")) {
    if (!is_program_on_path("avconv")) {
      die "Could not find ffmpeg nor avconv executable!";
    } else {
      @args = (
        "avconv",
        "-i", $in_file,
        "-bsf:a", "aac_adtstoasc",
        "-c", "copy",
        "-f", "mp4",
        $out_file
      );
    }
  } else {
    @args = (
      "ffmpeg",
      "-i", $in_file,
      "-absf", "aac_adtstoasc",
      "-c", "copy",
      "-f", "mp4",
      $out_file
    );
  }

  # Execute command
  if (system(@args) != 0) {
    die "Calling @args failed: $?";
  }

  return 1;
}

sub read_hls_playlist {
  my($browser, $url) = @_;

  $browser->get($url);
  if (!$browser->success) {
    die "Couldn't download m3u file, $url: " . $browser->response->status_line;
  }
  debug $browser->content;
  debug $browser->cookie_jar->as_string();

  my @lines = split(/\r?\n/, $browser->content);
  my %urltable = ();
  my $i = 0;

  # Fill the url table
  foreach my $line (@lines) {
    if ($line =~ /EXT-X-STREAM-INF/ && $line =~ /BANDWIDTH/) {
      $line =~ /BANDWIDTH=([0-9]*)/;
      $urltable{int($1)} = $lines[$i + 1];
    }
    $i++;
  }

  return %urltable;
}

sub download {
  my ($self, $args, $file, $browser) = @_;

  my $hls_url = $args->{args}->{hls_url};
  my $prefs   = $args->{args}->{prefs};

  $browser->cookie_jar( {} );
  $browser->add_header( Referer => undef);

  $browser->get($hls_url);
  my %urls = read_hls_playlist($browser, $hls_url);

  #  Sort the urls and select the suitable one based upon quality preference
  my $quality = $bitrate_index->{$prefs->{quality}};
  my $min = $quality < scalar(keys(%urls)) ? $quality : scalar(keys(%urls));
  my $key = (sort {int($b) <=> int($a)} keys %urls)[$min];

  my ($hls_base, $trail) = ($hls_url =~ m/(.*\/)(.*)\.m3u8/);
  my $filename_mp4 = $args->{flv};
  my $filename_ts = $args->{flv} . ".ts";
  my $filename_ts_segment = $args->{flv} . ".tsx";
  my $video_url = $urls{$key} =~ m/http(s?):\/\// ? $urls{$key} : $hls_base.$urls{$key};

  $browser->add_header( Referer => undef);

  $browser->get($video_url);
  if (! $browser->success) {
    die "Unable to read segments" . $browser->response->status_line;
  }

  my @lines = split(/\r?\n/, $browser->content);
  my @segments = ();
   
  # Fill the url table
  my $encrypt_method;
  my $encrypt_uri;
  my $hls_key;
  my $decrypt;

  foreach my $line (@lines) {
    if ($line !~ /#/) {
      push @segments, $line; 
    } elsif ($line =~ /#EXT-X-KEY:METHOD=([^,]*)/) {
      $encrypt_method = $1; 
      ($encrypt_uri) = $line =~ m%,URI=\"([^\"]*)"%;
    }
  }

  info "Encrypt $encrypt_method uri $encrypt_uri";
  if (defined $encrypt_method && $encrypt_method ne 'NONE') {
    die "Encryption method $encrypt_method is not supported" if $encrypt_method ne "AES-128";
  }
  my $i = 1;
  my $num_segs = @segments;
  info "Downloading segments";
  my $progress_bar = Term::ProgressBar->new($num_segs);

  open(my $fh_app, '>', $filename_ts) or die "Could not open file $filename_ts";
  binmode($fh_app);
  my $buffer;

  foreach my $url (@segments) {
    # Download and save each segment in a re-used segment file.
    # Otherwise, the process memory expands monotonically. Large downloads would use up
    # all memory and kill the process.
    $browser->get($url, ":content_file" => $filename_ts_segment);
    # Open the segment and append it to the TS file.
    open(SEG, '<', $filename_ts_segment) or die "Could not open file $filename_ts_segment";
    binmode(SEG);
    if (! defined $decrypt && defined $encrypt_uri) {
       $browser->get($encrypt_uri);
       die "Unable to get decryption key" if ! $browser->success;
       $hls_key = $browser->contents;
    }
    while (read(SEG, $buffer, 16384)) {
      print $fh_app $buffer;
    }
    close(SEG);
    $progress_bar->update($i);
    $i++;
  }
  
  # Remove the segment file as it is no longer needed.
  unlink $filename_ts_segment;
  close($fh_app);
  
  cleanup_audio($filename_ts, $filename_mp4);

  $self->{printable_filename} = $filename_mp4;

  unlink $filename_ts;
  return -s $filename_mp4; 
}
1;
