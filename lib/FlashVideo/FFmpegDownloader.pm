# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::FFmpegDownloader;

use strict;
use warnings;
use base 'FlashVideo::Downloader';
use FlashVideo::Utils;

sub download {
  my ($self, $ffmpeg_data, $file) = @_;

  $self->{printable_filename} = $file;
  my $executable;

  # Look for executable (ffmpeg or avconv)
  if (!is_program_on_path("ffmpeg")) {
    if (!is_program_on_path("avconv")) {
      die "Could not find ffmpeg nor avconv executable!";
    } else {
      $executable = "avconv";
    }
  } else {
    $executable = "ffmpeg";
  }

  # Prepend the executable to the list of arguments
  my @args = @{$ffmpeg_data->{args}};
  unshift @args, $executable;

  # Execute command
  if (system(@args) != 0) {
    die "Calling @args failed: $?";
  }

  # Return size of the downloaded file
  return -s $file;
}

1;
