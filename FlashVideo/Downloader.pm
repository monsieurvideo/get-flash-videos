# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Downloader;

use strict;
use FlashVideo::Utils;

sub new {
  my $class = shift;
  my $self = {};

  bless $self, $class;
  return $self;
}

sub play {
  my ($self, $url, $file, $browser) = @_;

  $self->{stream} = sub {
    $self->{stream} = undef;

    my $pid = fork;
    die "Fork failed" unless defined $pid;
    if(!$pid) {
      exec $self->replace_filename($::opt{player}, $file);
      die "Exec failed\n";
    }
  };

  $self->download($url, $file, $browser);
}

sub download {
  my ($self, $url, $file, $browser) = @_;

  $self->{filename} = $file;

  # Support resuming
  my $mode = (-e $file) ? '>>' : '>';
  my $offset;
  if (-e $file) {
    $offset = -s $file;

    my $response = $browser->head($url);

    # File might be fully downloaded, in which case there's nothing to
    # resume.
    if ($offset == $response->header('Content-Length')) {
      error "File $file has been fully downloaded.";
      $self->{stream}->() if defined $self->{stream};
      return;
    }
    
    info "File $file already exists, seeing if resuming is supported.";
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

  $self->{file} = $file;
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
        }

        if ($offset and !$response->header('Content-Range')) {
          error "Resuming failed - please delete $file and restart.";
          exit 1;
        }
        else {
          $self->{downloaded} = $offset unless $self->{downloaded};
        }

        my $fh = $self->{fh};
        print $fh $data;

        if(defined $self->{stream}) {
          if($self->{downloaded} > 300_000) {
            $self->{stream}->();
          }
        }

        if(!$self->{downloaded} && length $data > 16) {
          if(!$self->_check_magic($data)) {
            error "Sorry, file does not look like a media file, aborting.";
            exit 1;
          }
        }

        $self->{downloaded} += length $data;
        $self->progress;
    }, ':read_size_hint' => '10240');

  close $self->{fh};

  if ($browser->success) {
    info "\nDone. Saved " . $response->header('Content-Length') . " bytes "
          . "to $file.";
    return 1;
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

  if ($self->{content_length}) {
    my $percent = int(
      ($self->{downloaded} / $self->{content_length}) * 100
    );
    if ( ($percent != $self->{percent}) and $percent) {
      my $downloaded_kib = _bytes_to_kib($self->{downloaded});
      my $total_kib      = _bytes_to_kib($self->{content_length});
      print STDERR "\r$self->{filename}: $percent% " .
      "($downloaded_kib / $total_kib KiB)";
    }
    $self->{percent} = $percent;
  }
  else {
    # Handle lame servers that don't tell us how big the file is
    my $data_transferred = _bytes_to_kib($self->{downloaded});;
    if ($data_transferred != $self->{data_transferred}) {
      print STDERR "\r$self->{filename}: $data_transferred KiB";
    }
  }
}

sub _bytes_to_kib {
  return sprintf '%0.2f', ($_[0] / 1024)
}

sub replace_filename {
  my($self, $string, $filename) = @_;
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

  return $self->_check_magic($data);
}

sub _check_magic {
  my($self, $data) = @_;

  # This is a very simple check to ensure we have a media file.
  # The aim is to avoid downloading HTML, Flash, etc and claiming to have
  # succeeded.

  # FLV
  if(substr($data, 0, 3) eq 'FLV') {
    return 1;
  # ASF
  } elsif(substr($data, 0, 4) eq "\x30\x26\xb2\x75") {
    return 1;
  # ISO
  } elsif(substr($data, 4, 4) eq 'ftyp') {
    return 1;
  # Other QuickTime
  } elsif(substr($data, 4, 4) eq 'moov') {
    return 1;
  }

  return 0;
}

1;

