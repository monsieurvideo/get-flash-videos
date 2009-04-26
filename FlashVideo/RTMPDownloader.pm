# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::RTMPDownloader;

use strict;
use base 'FlashVideo::Downloader';
use Fcntl;
use FlashVideo::Utils;

sub download {
  my ($self, $rtmp_data) = @_;

  if (-e $rtmp_data->{flv}) {
    info "RTMP output filename '$rtmp_data->{flv}' already " .
                 "exists, asking rtmpdump to resume...";
    $rtmp_data->{resume} = '';
  }

  $self->{filename} = $rtmp_data->{flv};

  my($r_fh, $w_fh); # So Perl doesn't close them behind our back..

  if ($::opt{play} && exists $rtmp_data->{live}) {
    # Playing live stream, we pipe this straight to the player, rather than
    # saving on disk.
    delete $rtmp_data->{live};

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

  open my $rtmp_fh, "-|", "rtmpdump", map { ("--$_" => ($rtmp_data->{$_} || ())) } keys %$rtmp_data;

  my $buf = "";
  while(sysread($rtmp_fh, $buf, 512, length $buf) > 0) {
    my @parts = split /\r/, $buf;
    $buf = "";

    for(@parts) {
      # Hide almost everything from rtmpdump, it's less confusing this way.
      if(/^((?:WARNING|DEBUG|ERROR): .*)\n/) {
        debug $1;
      } elsif(/^([0-9.]+) KB(?: \(([0-9.]+)%\))?/) {
        $self->{downloaded} = $1 * 1024;
        my $percent = $2;

        if($self->{content_length} == 0 && $self->{downloaded} && $percent != 0) {
          # An approximation, but should be reasonable..
          $self->{content_length} = $self->{downloaded} / ($percent / 100);
        }

        $self->progress;
      } elsif(/\n$/) {
        info $_ if /\w/;
      } else {
        # Hack; assume lack of newline means it was an incomplete read..
        $buf = $_;
      }
    }

    # Should be about enough..
    if(defined $self->{stream} && $self->{downloaded} > 300_000) {
      $self->{stream}->();
      $self->{stream} = undef;
    }
  }

  if(!$self->check_file($rtmp_data->{flv})) {
    error "Download failed, no valid file downloaded";
    unlink $rtmp_data->{flv};
    return 0;
  }

  # Note we hide the progress, our download guess was only an estimate, so this
  # should be less confusing..
  info "\rDone. Saved", -s $self->{filename}, "bytes to $self->{filename}.";

  return 1;
}

1;
