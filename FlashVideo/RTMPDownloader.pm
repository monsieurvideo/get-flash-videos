# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::RTMPDownloader;

use strict;
use base 'FlashVideo::Downloader';
use Fcntl;
use IPC::Open3;
use Symbol qw(gensym);
use FlashVideo::Utils;

sub download {
  my ($self, $rtmp_data) = @_;

  $self->{printable_filename} = $rtmp_data->{flv};

  my $file = $rtmp_data->{flv} = $self->get_filename($rtmp_data->{flv});

  if (-e $file && !$rtmp_data->{live}) {
    info "RTMP output filename '$self->{printable_filename}' already " .
                 "exists, asking to resume...";
    $rtmp_data->{resume} = '';
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

  debug "Running $prog", 
    join(" ", map { ("--$_" => $rtmp_data->{$_} ? $self->shell_escape($rtmp_data->{$_}) : ()) } keys
        %$rtmp_data);

  my($in, $out, $err);
  $err = gensym;
  open3($in, $out, $err, $prog,
    map { ("--$_" => ($rtmp_data->{$_} || ())) } keys %$rtmp_data);

  my $complete = 0;
  my $buf = "";
  while(sysread($err, $buf, 128, length $buf) > 0) {
    my @parts = split /\r/, $buf;
    $buf = "";

    for(@parts) {
      # Hide almost everything from rtmpdump, it's less confusing this way.
      if(/^((?:DEBUG:|WARNING:|Closing connection|ERROR: No playpath found).*)\n/) {
        debug "$prog: $1";
      } elsif(/^(ERROR: .*)\n/) {
        info "$prog: $1";
      } elsif(/^([0-9.]+) kB(?: \(([0-9.]+)%\))?/i) {
        $self->{downloaded} = $1 * 1024;
        my $percent = $2;

        if($self->{downloaded} && $percent != 0) {
          # An approximation, but should be reasonable if we don't have the size.
          $self->{content_length} = $self->{downloaded} / ($percent / 100);
        }

        $self->progress;
      } elsif(/\n$/) {
        for my $l(split /\n/) {
          if($l =~ /^[A-F0-9]{,2}(?:\s+[A-F0-9]{2})*\s*$/) {
            debug $l;
          } elsif($l =~ /Download complete/) {
            $complete = 1;
          } elsif($l =~ /\s+filesize\s+(\d+)/) {
            $self->{content_length} = $1;
          } elsif($l =~ /\w/) {
            info $l;
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

  if(-s $file < 100 || !$self->check_file($file)) {
    error "Download failed, no valid file downloaded";
    unlink $rtmp_data->{flv};
    return 0;
  }

  if($self->{percent} < 95) {
    info "\n$prog exited early? Incomplete download possible -- try running again to resume.";
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

1;
