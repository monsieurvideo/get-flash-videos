# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Tv4play;
use strict;
use warnings;
use FlashVideo::Utils;
use List::Util qw(reduce);

our $VERSION = '0.02';
sub Version() { $VERSION;}

my $bitrate_index = {
  high   => 0,
  medium => 1,
  low    => 2
};

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;
  my $video_id = ($embed_url =~ /video_id=([0-9]*)/)[0];
  my $smi_url = "http://premium.tv4play.se/api/web/asset/$video_id/play?protocol=hls";
  my $title = extract_title($browser);
  $browser->get($smi_url);
  my $content = from_xml($browser);
  my $subtitle_url;
  my $hls_m3u = "";
  my $hls_base;

  foreach my $item (@{ $content->{items}->{item} || [] }) {

    # Find playlist item
    if ($item->{base} =~ m/.*\.m3u8/) {
      $hls_m3u = $item->{url};
      $hls_base = $item->{url};
      # Strip to base
      $hls_base =~ s/master\.m3u8//;
    }

    # Set subtitles
    if ($item->{mediaFormat} eq 'smi') {
      $subtitle_url = $item->{url};
    }
  }

  if ($hls_m3u eq "") {die "No HLS stream found!"};

  # Download subtitles
  if ($prefs->{subtitles} == 1) {
    if (not $subtitle_url eq '') {
      $browser->get("$subtitle_url");
      if (!$browser->success) {
        info "Couldn't download subtitles: " . $browser->status_line;
      } else {
        my $srt_filename = title_to_filename($title, "srt");
        info "Saving subtitles as " . $srt_filename;
        open my $srt_fh, '>', $srt_filename
          or die "Can't open subtitles file $srt_filename: $!";
        binmode $srt_fh, ':utf8';
        print $srt_fh $browser->content;
        close $srt_fh;
      }
    } else {
      info "No subtitles found";
    }
  }

  my %urls = read_hls_playlist($browser, $hls_m3u);

  # Sort the urls and select the suitable one based upon quality preference
  my $quality = $bitrate_index->{$prefs->{quality}};
  my $min = $quality < scalar(keys(%urls)) ? $quality : scalar(keys(%urls));
  my $key = (sort {int($b) <=> int($a)} keys %urls)[$min];

  my $video_url = $urls{$key};
  my $filename = title_to_filename($title, "mp4");

  my $url = $video_url =~ m/http:\/\// ? $video_url : $hls_base.$video_url;

  # Set the arguments for ffmpeg
  my @ffmpeg_args = (
    "-i", "$url",
    "-acodec", "copy",
    "-vcodec", "copy",
    "-absf", "aac_adtstoasc",
    "-f", "mp4",
    "$filename"
  );

  return {
    downloader => "ffmpeg",
    flv        => $filename,
    args       => \@ffmpeg_args
  };
}

1;
