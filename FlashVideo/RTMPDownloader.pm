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

  if (-e $rtmp_data->{flv} && !$rtmp_data->{live}) {
    info "RTMP output filename '$rtmp_data->{flv}' already " .
                 "exists, asking rtmpdump to resume...";
    $rtmp_data->{resume} = '';
  }

  $self->{filename} = $rtmp_data->{flv};

  my($r_fh, $w_fh); # So Perl doesn't close them behind our back..

  if ($rtmp_data->{live} && $::opt{play}) {
    # Playing live stream, we pipe this straight to the player, rather than
    # saving on disk.
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

  debug "Running rtmpdump", 
    join(" ", map { ("--$_" => $rtmp_data->{$_} ? $self->shell_escape($rtmp_data->{$_}) : ()) } keys
        %$rtmp_data);

  my($in, $out, $err);
  $err = gensym;
  open3($in, $out, $err, "rtmpdump",
    map { ("--$_" => ($rtmp_data->{$_} || ())) } keys %$rtmp_data);

  my $buf = "";
  while(sysread($err, $buf, 512, length $buf) > 0) {
    my @parts = split /\r/, $buf;
    $buf = "";

    for(@parts) {
      # Hide almost everything from rtmpdump, it's less confusing this way.
      if(/^((?:DEBUG:|WARNING:|Closing connection|ERROR: No playpath found).*)\n/) {
        debug "rtmpdump: $1";
      } elsif(/^(ERROR: .*)\n/) {
        info "rtmpdump: $1";
      } elsif(/^([0-9.]+) KB(?: \(([0-9.]+)%\))?/) {
        $self->{downloaded} = $1 * 1024;
        my $percent = $2;

        if($self->{downloaded} && $percent != 0) {
          # An approximation, but should be reasonable if we don't have the size.
          $self->{content_length} = $self->{downloaded} / ($percent / 100);
        }

        $self->progress;
      } elsif(/\n$/) {
        for my $l(split /\n/) {
          info $l if /\w/;
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

  if(!$self->check_file($rtmp_data->{flv})) {
    error "Download failed, no valid file downloaded";
    unlink $rtmp_data->{flv};
    return 0;
  }

  if($self->{percent} > 95) {
    # Note we hide the progress, our download guess was only an estimate, so this
    # should be less confusing..
    info "\rDone. Saved", -s $self->{filename}, "bytes to $self->{filename}.";
  } else {
    info "\nrtmpdump exited early? Incomplete download possible -- try running again to resume.";
  }

  return 1;
}

1;
