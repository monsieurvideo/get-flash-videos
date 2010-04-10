# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::RTMPDownloader;

use strict;
use base 'FlashVideo::Downloader';
use Fcntl;
use IPC::Open3;
use Symbol qw(gensym);
use FlashVideo::Utils;

use constant LATEST_RTMPDUMP => 2.2;

sub download {
  my ($self, $rtmp_data) = @_;

  $self->{printable_filename} = $rtmp_data->{flv};

  my $file = $rtmp_data->{flv} = $self->get_filename($rtmp_data->{flv});

  if (-s $file && !$rtmp_data->{live}) {
    info "RTMP output filename '$self->{printable_filename}' already " .
                 "exists, asking to resume...";
    $rtmp_data->{resume} = '';
  }

  if(my $socks = FlashVideo::Mechanize->new->get_socks_proxy) {
    $rtmp_data->{socks} = $socks;
  }

  my($r_fh, $w_fh); # So Perl doesn't close them behind our back..

  if ($rtmp_data->{live} && $::opt{play}) {
    # Playing live stream, we pipe this straight to the player, rather than
    # saving on disk.
    # XXX: The use of /dev/fd could go away now rtmpdump supports streaming to
    # STDOUT.
   
    pipe($r_fh, $w_fh);

    my $pid = fork;
    die "Fork failed" unless defined $pid;
    if(!$pid) {
      fcntl $r_fh, F_SETFD, ~FD_CLOEXEC;
      exec $self->replace_filename($::opt{player}, "/dev/fd/" . fileno $r_fh);
      die "Exec failed\n";
    }

    fcntl $w_fh, F_SETFD, ~FD_CLOEXEC;
    $rtmp_data->{flv} = "/dev/fd/" . fileno $w_fh;

    $self->{stream} = undef;
  }

  my $prog = $self->get_rtmp_program;

  if($prog eq 'flvstreamer' && ($rtmp_data->{rtmp} =~ /^rtmpe:/ || $rtmp_data->{swfhash})) {
    error "FLVStreamer does not support "
      . ($rtmp_data->{swfhash} ? "SWF hashing" : "RTMPE streams")
      . ", please install rtmpdump.";
    exit 1;
  }

  if($::opt{debug}) {
    $rtmp_data->{verbose} = undef;
  }

  my($return, @errors) = $self->run($prog, $rtmp_data);

  if($return != 0 && "@errors" =~ /failed to connect/i) {
    # Try port 443 as an alternative
    info "Couldn't connect on RTMP port, trying port 443 instead";
    $rtmp_data->{port} = 443;
    ($return, @errors) = $self->run($prog, $rtmp_data);
  }

  if(-s $file < 100 || !$self->check_file($file)) {
    # This avoids trying to resume an invalid file
    error "Download failed, no valid file downloaded";
    unlink $rtmp_data->{flv};
    return 0;
  }

  if($return == 2) {
    info "\nDownload incomplete -- try running again to resume.";
    return 0;
  } elsif($return) {
    info "\nDownload failed.";
    return 0;
  }

  return -s $file;
}

sub get_rtmp_program {
  if(is_program_on_path("rtmpdump")) {
    return "rtmpdump";
  } elsif(is_program_on_path("flvstreamer")) {
    return "flvstreamer";
  }

  # Default to rtmpdump
  return "rtmpdump";
}

sub run {
  my($self, $prog, $rtmp_data) = @_;

  debug "Running $prog", 
    join(" ", map { ("--$_" => $rtmp_data->{$_} ? $self->shell_escape($rtmp_data->{$_}) : ()) } keys
        %$rtmp_data);

  my($in, $out, $err);
  $err = gensym;

  my $pid = open3($in, $out, $err, $prog,
    map { ("--$_" => ($rtmp_data->{$_} || ())) } keys %$rtmp_data);

  # Windows doesn't send signals to child processes, so we need to do it
  # manually to ensure that we don't have stray rtmpdump processes.
  local $SIG{INT};
  if ($^O =~ /mswin/i) {
    $SIG{INT} = sub {
      kill 'TERM', $pid;
      exit;
    };
  } 

  my $complete = 0;
  my $buf = "";
  my @error;

  while(sysread($err, $buf, 128, length $buf) > 0) {
    $buf =~ s/\015\012/\012/g;

    my @parts = split /\015/, $buf;
    $buf = "";

    for(@parts) {
      # Hide almost everything from rtmpdump, it's less confusing this way.
      if(/^((?:DEBUG:|WARNING:|Closing connection|ERROR: No playpath found).*)\n/) {
        debug "$prog: $1";
      } elsif(/^(ERROR: .*)\012/) {
        push @error, $1;
        info "$prog: $1";
      } elsif(/^([0-9.]+) kB(?:\s+\/ \S+ sec)?(?: \(([0-9.]+)%\))?/i) {
        $self->{downloaded} = $1 * 1024;
        my $percent = $2;

        if($self->{downloaded} && $percent != 0) {
          # An approximation, but should be reasonable if we don't have the size.
          $self->{content_length} = $self->{downloaded} / ($percent / 100);
        }

        $self->progress;
      } elsif(/\012$/) {
        for my $l(split /\012/) {
          if($l =~ /^[A-F0-9]{,2}(?:\s+[A-F0-9]{2})*\s*$/) {
            debug $l;
          } elsif($l =~ /Download complete/) {
            $complete = 1;
          } elsif($l =~ /\s+filesize\s+(\d+)/) {
            $self->{content_length} = $1;
          } elsif($l =~ /\w/) {
            print STDERR "\r" if $self->{downloaded};
            info $l;

            if($l =~ /^RTMPDump v([0-9.]+)/ && $1 < LATEST_RTMPDUMP) {
              error "==== Using the latest version of RTMPDump (version "
                . LATEST_RTMPDUMP . ") is recommended. ====";
            }
          }
        }

        if(/open3/) {
          error "\nMake sure you have 'rtmpdump' or 'flvstreamer' installed and available on your PATH.";
          return 0;
        }
      } else {
        # Hack; assume lack of newline means it was an incomplete read..
        $buf = $_;
      }
    }

    # Should be about enough..
    if(defined $self->{stream} && $self->{downloaded} > 300_000) {
      $self->{stream}->();
    }
  }

  waitpid $pid, 0;
  return $? >> 8, @error;
}

1;
