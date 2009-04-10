# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Downloader;

sub new {
  my $class = shift;
  my $self = {};

  bless $self, $class;
  return $self;
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
      print STDERR "File $file has been fully downloaded.\n";
      return;
    }

    print STDERR "File $file already exists, seeing if resuming is supported.\n";
    if (!$response->header('Accept-Ranges')) {
      if(!$::yes) {
        print STDERR "This server doesn't explicitly support resuming.\n" .
                   "Do you want to try resuming anyway (y/n)?\n";
        chomp(my $answer = <STDIN>);
        if (!$answer or lc($answer) eq 'n') {
          undef $offset;
          $mode = '>';
        }
      }
    }
    else {
      print STDERR "Server supports resuming, attempting to resume.\n";
    }
  }

  $self->{file} = $file;
  open my $video_fh, $mode, $file or die $!;
  binmode $video_fh;
  $self->{fh} = $video_fh; 

  print STDERR "Downloading $url...\n";
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
          print STDERR "Resuming failed - please delete $file and restart.\n";
          exit;
        }
        else {
          $self->{downloaded} = $offset unless $self->{downloaded};
        }

        my $fh = $self->{fh};
        print $fh $data;

        if(!$self->{downloaded}) {
          if(!$self->_check_magic($data)) {
            print STDERR "Sorry, file does not look like a media file, aborting.\n";
            exit 1;
          }
        }

        $self->{downloaded} += length $data;
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
            print STDERR "Now got $data_transferred KiB\n";
          }
        }
    }, ':read_size_hint' => '10240');

  close $self->{fh};

  if ($browser->success) {
    print STDERR
      "\nDone. Saved " . $response->header('Content-Length') . " bytes "
          . "to $file.\n";
    return 1;
  } else {
    unlink $file unless -s $file;
    print STDERR "Couldn't download $url: " . 
          $browser->response->status_line . "\n";
    return 0;
  }
}

sub _bytes_to_kib {
  return sprintf '%0.2f', ($_[0] / 1024)
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

