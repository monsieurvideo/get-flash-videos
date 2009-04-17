# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::RTMPDownloader;

use strict;
use base 'FlashVideo::Downloader';

sub download {
  my ($self, $rtmp_data) = @_;

  if (-e $rtmp_data->{flv}) {
    print STDERR "RTMP output filename '$rtmp_data->{flv}' already " .
                 "exists, asking rtmpdump to resume...\n";
    $rtmp_data->{resume} = '';
  }

  print STDERR "Running rtmpdump ",
    join(" ", map { ("--$_" => "'" . $rtmp_data->{$_} . "'") } keys %$rtmp_data), "\n";

  system "rtmpdump", map { ("--$_" => $rtmp_data->{$_}) } keys %$rtmp_data;

  if(!$self->check_file($rtmp_data->{flv})) {
    print STDERR "Download failed, no valid file downloaded\n";
    unlink $rtmp_data->{flv};
  }
}

1;
