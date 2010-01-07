# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Downloader;

use strict;
use FlashVideo::Utils;

sub new {
  my $class = shift;

  my $self = {
    has_readkey => eval { require Term::ReadKey }
  };

  bless $self, $class;
  return $self;
}

sub play {
  my ($self, $url, $file, $browser) = @_;

  $self->{stream} = sub {
    $self->{stream} = undef;

    if ($^O =~ /MSWin/i and $::opt{player} eq "VLC") {
      # mplayer is the default - but most Windows users won't have it. If no
      # other player is specified, check to see if VLC is installed, and if so,
      # use it. In future perhaps this should use Win32::FileOp's
      # ShellExecute (possibly with SW_SHOWMAXIMIZED depending on video
      # resolution) to open in the default media player. However, this
      # isn't ideal as media players tend to pinch each other's file
      # associations.
      if (my $vlc_binary = FlashVideo::Utils::get_vlc_exe_from_registry()) {
        require Win32::Process;
        require File::Basename;
        require File::Spec;
        $file = File::Spec->rel2abs($file);

        # For absolutely no valid reason, Win32::Process::Create requires
        # *just* the EXE filename (for example vlc.exe) and then any
        # subsequent parameters as the "commandline parameters". Since
        # when is the EXE filename (which, of course, has already been
        # supplied) a commandline parameter?!
        my $binary_no_path = File::Basename::basename $vlc_binary;

        my $binary_just_path = File::Basename::dirname $vlc_binary; 

        # Note info() is used because the player is launched when >=n% of
        # the video is complete (so the user doesn't have to wait until
        # it's all downloaded). die() wouldn't be good as we then wouldn't
        # download the remainder of the video.
        my $process;
        Win32::Process::Create(
          $process,
          $vlc_binary,
          "$binary_no_path $file",
          1,
          32, # NORMAL_PRIORITY_CLASS
          $binary_just_path,
        ) or info "Couldn't launch VLC ($vlc_binary): " . Win32::GetLastError();
      }
    }
    else {
      # *nix
      my $pid = fork;
      die "Fork failed" unless defined $pid;
      if(!$pid) {
        exec $self->replace_filename($::opt{player}, $file);
        die "Exec failed\n";
      }
    }
  };

  $self->download($url, $file, $browser);
}

sub download {
  my ($self, $url, $file, $browser) = @_;

  $self->{printable_filename} = $file;

  $file = $self->get_filename($file);

  # Support resuming
  my $mode = (-e $file) ? '>>' : '>';
  my $offset;
  if (-e $file) {
    $offset = -s $file;

    my $response = $browser->head($url);

    # File might be fully downloaded, in which case there's nothing to
    # resume.
    if ($offset == $response->header('Content-Length')) {
      error "File $self->{printable_filename} has been fully downloaded.";
      $self->{stream}->() if defined $self->{stream};
      return;
    }
    
    info "File $self->{printable_filename} already exists, seeing if resuming is supported.";
    if (!$response->header('Accept-Ranges')) {
      if(!$::opt{yes}) {
        error "This server doesn't explicitly support resuming.\n" .
                   "Do you want to try resuming anyway (y/n)?";
        chomp(my $answer = <STDIN>);
        if (!$answer or lc($answer) eq 'n') {
          undef $offset;
          $mode = '>';
        }
      }
    }
    else {
      info "Server supports resuming, attempting to resume.";
    }
  }

  open my $video_fh, $mode, $file or die $!;
  binmode $video_fh;
  $self->{fh} = $video_fh; 

  info "Downloading $url...";
  if ($offset) {
    $browser->add_header("Range", "bytes=$offset-");
  }
  my $response = $browser->get($url, 
    ':content_cb' => sub { 
        my ($data, $response) = @_;

        # If we're resuming, Content-Length will just be the length of the
        # range the server is sending back, so add on the offset to make %
        # completed accurate.
        if (!$self->{content_length}) {
          $self->{content_length} = $response->header('Content-Length')
                                    + $offset;

          if($response->header('Content-encoding') =~ /gzip/i) {
            eval { require Compress::Zlib; } or do {
              error "Must have Compress::Zlib installed to download from this site.\n";
              exit 1;
            };

            my($inflate, $status) = Compress::Zlib::inflateInit(
              -WindowBits => -Compress::Zlib::MAX_WBITS());
            error "inflateInit failed: $status" if $status;

            $self->{filter} = sub {
              my($data) = @_;

              if(!$self->{downloaded}) {
                Compress::Zlib::_removeGzipHeader(\$data);
              }

              my($output, $status) = $inflate->inflate($data);
              return $output;
            }
          }
        }

        if ($offset and !$response->header('Content-Range')) {
          error "Resuming failed - please delete $self->{printable_filename} and restart.";
          exit 1;
        }
        else {
          $self->{downloaded} = $offset unless $self->{downloaded};
        }

        my $len = length $data;

        if($self->{filter}) {
          $data = $self->{filter}->($data);
        }

        my $fh = $self->{fh};
        print $fh $data || die "Unable to write to '$self->{printable_filename}': $!\n";

        if(defined $self->{stream}) {
          if($self->{downloaded} > 300_000) {
            $self->{stream}->();
          }
        }

        if(!$self->{downloaded} && length $data > 16) {
          if(!$self->check_magic($data)) {
            error "Sorry, file does not look like a media file, aborting.";
            exit 1;
          }
        }

        $self->{downloaded} += $len;
        $self->progress;
    }, ':read_size_hint' => 16384);

  if($browser->response->header("X-Died")) {
    error $browser->response->header("X-Died");
  }

  close $self->{fh} || die "Unable to write to '$self->{printable_filename}': $!";

  if ($browser->success) {
    return $self->{downloaded} - $offset;
  } else {
    unlink $file unless -s $file;
    error "Couldn't download $url: " .  $browser->response->status_line;
    return 0;
  }
}

sub progress {
  my($self) = @_;

  return unless -t STDERR;
  return if $::opt{quiet};

  my $progress_text;

  if ($self->{content_length}) {
    my $percent = int(
      ($self->{downloaded} / $self->{content_length}) * 100
    );
    if ($percent && ($percent != $self->{percent} || time != $self->{last_time})) {
      my $downloaded_kib = _bytes_to_kib($self->{downloaded});
      my $total_kib      = _bytes_to_kib($self->{content_length});
      $progress_text = ": $percent% ($downloaded_kib / $total_kib KiB)";
      $self->{last_time} = time;
      $self->{percent} = $percent;
    }
  } else {
    # Handle lame servers that don't tell us how big the file is
    my $data_transferred = _bytes_to_kib($self->{downloaded});;
    if ($data_transferred != $self->{data_transferred}) {
      $progress_text = ": $data_transferred KiB";
    }
  }

  if($progress_text) {
    my $width = get_terminal_width();

    my $filename = $self->{printable_filename};
    my $filename_len = $width - length($progress_text);

    if($filename_len < length $filename) {
      # 3 for "..."
      my $rem = 3 + length($filename) - $filename_len;
      # Try and chop off somewhere near the end, but not the very end..
      my $pos = length($filename) - $rem - 12;
      $pos = 0 if $pos < 0;
      substr($filename, $pos, $rem) = "...";
    }

    syswrite STDERR, "\r$filename$progress_text";
  }
}

sub _bytes_to_kib {
  return sprintf '%0.2f', ($_[0] / 1024)
}

sub replace_filename {
  my($self, $string, $filename) = @_;
  $string .= " %s" unless $string =~ /%s/;
  my $esc = $self->shell_escape($filename);
  $string =~ s/['"]?%s['"]?/$esc/g;
  return $string;
}

sub shell_escape {
  my($self, $file) = @_;

  # Shell escape the given filename
  $file =~ s/'/'\\''/g;
  return "'$file'";
}

sub check_file {
  my($self, $file) = @_;

  open my $fh, "<", $file;
  binmode $fh;
  my $data;
  read $fh, $data, 16;

  return $self->check_magic($data);
}

sub check_magic {
  my($self, $data) = @_;

  # This is a very simple check to ensure we have a media file.
  # The aim is to avoid downloading HTML, Flash, etc and claiming to have
  # succeeded.

  # FLV
  if(substr($data, 0, 3) eq 'FLV') {
    return 1;
  # MP3
  } elsif(substr($data, 0, 3) eq 'ID3') {
    return 1;
  # ASF
  } elsif(substr($data, 0, 4) eq "\x30\x26\xb2\x75") {
    return 1;
  # ISO
  } elsif(substr($data, 4, 4) eq 'ftyp') {
    return 1;
  # Other QuickTime
  } elsif(substr($data, 4, 4) eq 'moov' || substr($data, 4, 4) eq 'mdat') {
    return 1;
  }

  return 0;
}

sub get_filename {
  my($self, $file) = @_;

  # On windows the filename needs to be in the codepage of the system..
  if($^O =~ /MSWin/i) {
    $file = Encode::encode(get_win_codepage(), $file);
    # This may have added '?' as subsition characters, replace with '_'
    $file =~ s/\?/_/g;
  }

  return $file;
}

1;

