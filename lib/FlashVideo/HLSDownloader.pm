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
  my $video_url = $urls{$key} =~ m/http:\/\// ? $urls{$key} : $hls_base.$urls{$key};

  $browser->get($video_url);

  my @lines = split(/\r?\n/, $browser->content);
  my @segments = ();
   
  # Fill the url table
  foreach my $line (@lines) {
    if ($line !~ /#/) {
      push @segments, $line; 
    }
  }

  unlink $filename_ts; # Remove ts file if present

  my $i = 1;
  my $num_segs = @segments;
  info "Downloading segments";
  my $progress_bar = Term::ProgressBar->new($num_segs);

  foreach my $url (@segments) {
    $browser->get($url);
    open(my $fh_app, '>>', $filename_ts) or die "Could not open file append.ts";
    print $fh_app $browser->content;
    $progress_bar->update($i);
    $i++;
  }

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

  unlink $filename_ts;
  return -s $filename_mp4; 
}
1;
