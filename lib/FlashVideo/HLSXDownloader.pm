# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::HLSXDownloader;

use strict;
use warnings;
use base 'FlashVideo::Downloader';
use FlashVideo::Utils;
use FlashVideo::JSON;
use FlashVideo::Mechanize;
use Term::ProgressBar;
use Crypt::Rijndael;

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


sub m3u8_attributes {
  my $a = shift;
  my $info = shift;

  while ($a =~ m/([A-Z0-9-]+)=(\"[^\"]+\"|[^\",]+)(?:,|$)/g) {
    my $key = $1;
    my $val = $2;
    $val =~ s/^\"(.*)\"$/$1/;
    $info->{$key} = $val;
  }
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
  my $hls_key;
  my $decrypt;

  foreach my $line (@lines) {
    if ($line !~ /#/) {
      # push non-blank lines
      push @segments, $line if $line !~ /^\s*$/; 
    }
  }

  my $i = 1;
  my $num_segs = @segments;
  info "Downloading segments";
  my $progress_bar = Term::ProgressBar->new($num_segs);

  open(my $fh_app, '>', $filename_ts) or die "Could not open file $filename_ts";
  binmode($fh_app);
  my $buffer;

  my $media_sequence = 0;
  my %decrypt_info = ( 'METHOD', 'NONE'); 
  my %byte_range = ();
  my $segment_index = 0;

  foreach my $line (@lines) {
    # skip empty lines
    if ($line !~ /^\s*$/) {
      if ( $line !~ /#/) {
        # segment line
        $segment_index += 1;
        # to do skip if restarted
        # and havent reaach last segment added yet.
        my $url = $line;
        if ($line !~ m%https?://%) {
          # to do add manifest url to front to form url
        }
        if (%byte_range) {
          $browser->add_header('Range' => 'bytes='.$byte_range{'start'}.'-'. $byte_range{'end'});
        } else {
          $browser->delete_header('Range');
        }

        # Download and save each segment in a re-used segment file.
        # Otherwise, the process memory expands monotonically. Large downloads would use up
        # all memory and kill the process.
        $browser->get($url, ":content_file" => $filename_ts_segment);
        # Open the segment and append it to the TS file.
        open(SEG, '<', $filename_ts_segment) or die "Could not open file $filename_ts_segment";
        binmode(SEG);

        my $crypt;
        if ($decrypt_info{'METHOD'} eq 'AES-128') {
          my $iv;
          if (defined $decrypt_info{'IV'}) {
            $iv =$decrypt_info{'IV'}
          } else {
            $iv = pack('x8Q', $media_sequence);
          }
          if (! defined $decrypt_info{'KEY'}) {
            if (defined $decrypt_info{'URI'}) {
              $browser->get($decrypt_info{'URI'});
              my $hls_key = $browser->content;
              # to do pad key error checks.
              my $len = length($hls_key);
              if ($len < 16) {
                 $hls_key = "\0" x (16 - $len) . $hls_key;
              }
              $decrypt_info{'KEY'} = $hls_key;
              info "Set KEY ".$decrypt_info{'KEY'};
            }
          }
          $crypt = Crypt::Rijndael->new($decrypt_info{'KEY'}, Crypt::Rijndael::MODE_CBC() );
          $crypt->set_iv($iv);
          while (read(SEG, $buffer, 16384)) {
            print $fh_app $crypt->decrypt($buffer);
          }
          info "Output decrypted segment";
        } else {
          while (read(SEG, $buffer, 16384)) {
            print $fh_app $buffer;
          }
        } 
        close(SEG);
        $progress_bar->update($i);
        $i++;
        $media_sequence++;
      } else {
        # line begins with #
        if ($line =~ /#EXT-X-KEY:/) {
          my %m3u8_info;
          m3u8_attributes($line, \%m3u8_info);
          $decrypt_info{'METHOD'} = $m3u8_info{'METHOD'};
          $decrypt_info{'KEY'} = $m3u8_info{'KEY'};
          $decrypt_info{'IV'} = $m3u8_info{'IV'};
          $decrypt_info{'URI'} = $m3u8_info{'URI'};
          info "Method ".$decrypt_info{'METHOD'} if defined $decrypt_info{'METHOD'};
          info "Key ".$decrypt_info{'KEY'} if defined $decrypt_info{'KEY'};
          info "IV ".$decrypt_info{'IV'} if defined $decrypt_info{'IV'};
          info "URI ".$decrypt_info{'URI'} if defined $decrypt_info{'URI'};
        } elsif ($line =~ /#EXT-X-MEDIA-SEQUENCE/) {
          my $cmd;
          ($cmd, $media_sequence) = split(/:/, $line);
          info "Media sequence = $media_sequence";
        } elsif ($line =~ /#EXT-X-BYTERANGE/) {
          my ($cmd, $range) = split(/:/, $line);
          if ($range =~ /@/) {
          my ($seg_len, $start) = split(/@/, $range);
             $byte_range{'start'} = $start;
             $byte_range{'end'} = $start + $seg_len;
          } else {
             $byte_range{'start'} = $byte_range{'end'};
             $byte_range{'end'} += $range;
          }
          info "Byte Range : ".$byte_range{'start'}." to ".$byte_range{'end'};
           
        } elsif ($line =~ /#EXTINF/) {
          my ($cmd, $dt) = split(/:/, $line);
          my ($dur, $stitle) = split(/,/, $dt);
          info "Seg duration $dur title $stitle";
        } else {
          info "Ignored line : $line";
        }
      }
    }  
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
