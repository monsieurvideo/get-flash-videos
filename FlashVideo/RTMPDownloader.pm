package FlashVideo::RTMPDownloader;

use base 'FlashVideo::Downloader';

sub download {
  my ($self, $rtmpdump_command) = @_;

  print STDERR "Running rtmpdump command:\n$rtmpdump_command\n"; 

  system $rtmpdump_command;
}

1;
