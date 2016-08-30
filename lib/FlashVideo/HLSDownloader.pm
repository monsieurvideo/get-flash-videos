# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::HLSDownloader;

use strict;
use warnings;
use base 'FlashVideo::Downloader';
use FlashVideo::Utils;
use FlashVideo::FFmpegDownloader;
use FlashVideo::JSON;
use Term::ProgressBar;

my $bitrate_index = {
  high   => 0,
  medium => 1,
  low    => 2
};

sub download {
  my ($self, $args, $file, $browser) = @_;

  my $hls_url = $args->{args}->{hls_url};
  my $prefs   = $args->{args}->{prefs};

  $browser->get($hls_url);
  my %urls = read_hls_playlist($browser, $hls_url);

  #  Sort the urls and select the suitable one based upon quality preference
  my $quality = $bitrate_index->{$prefs->{quality}};
  my $min = $quality < scalar(keys(%urls)) ? $quality : scalar(keys(%urls));
  my $key = (sort {int($b) <=> int($a)} keys %urls)[$min];

  my ($hls_base, $trail) = ($hls_url =~ m/(.*\/)(.*)\.m3u8/);
  my $filename_mp4 = $args->{flv};
  my $filename_ts = $args->{flv} . ".ts";
  my $filename_ts_segment = $args->{flv} . ".tsx";
  my $video_url = $urls{$key} =~ m/http(s?):\/\// ? $urls{$key} : $hls_base.$urls{$key};

  $browser->get($video_url);

  my @lines = split(/\r?\n/, $browser->content);
  my @segments = ();
   
  # Fill the url table
  foreach my $line (@lines) {
    if ($line !~ /#/) {
      push @segments, $line; 
    }
  }

  my $i = 1;
  my $num_segs = @segments;
  info "Downloading segments";
  my $progress_bar = Term::ProgressBar->new($num_segs);

  open(my $fh_app, '>', $filename_ts) or die "Could not open file $filename_ts";
  binmode($fh_app);
  my $buffer;

  foreach my $url (@segments) {
    # Download and save each segment in a re-used segment file.
    # Otherwise, the process memory expands monotonically. Large downloads would use up
    # all memory and kill the process.
    $browser->get($url, ":content_file" => $filename_ts_segment);
    # Open the segment and append it to the TS file.
    open(SEG, '<', $filename_ts_segment) or die "Could not open file $filename_ts_segment";
    binmode(SEG);
    while (read(SEG, $buffer, 16384)) {
      print $fh_app $buffer;
    }
    close(SEG);
    $progress_bar->update($i);
    $i++;
  }
  
  # Remove the segment file as it is no longer needed.
  unlink $filename_ts_segment;
  close($fh_app);
  
  # Use ffmpeg to clean up audio
  my @ffmpeg_args = (
    "-i", $filename_ts,
    "-absf", "aac_adtstoasc",
    "-c", "copy",
    "-f", "mp4",
    $filename_mp4
  );

  my $dl_args = { 
    downloader => "ffmpeg",
    flv        => $filename_mp4,
    args       => \@ffmpeg_args
  };

  my $ffmpeg_downloader = FlashVideo::FFmpegDownloader->new;
  $ffmpeg_downloader->download($dl_args, $filename_mp4);

  $self->{printable_filename} = $filename_mp4;

  unlink $filename_ts;
  return -s $filename_mp4; 
}
1;
