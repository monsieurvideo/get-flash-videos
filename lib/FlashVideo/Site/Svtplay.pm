# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Svtplay;
use strict;
use FlashVideo::Utils;

my $encode_rates = {
     "ultralow" => 320,
     "low" => 850,
     "medium" => 1400, 
     "high" => 2400 };

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;
  my @rtmpdump_commands;
  my $url;
  my $low;
  my $ultralow;
  my $medium;
  my $high;
  my $data = ($browser->content =~ /dynamicStreams=(.*?)&/)[0];
  my @values = split(/\|/, $data); 
  foreach my $val (@values) {
    if (($val =~ m/url:(.*?),bitrate:2400/)){
       $high = ($val =~ /url:(.*?),bitrate:2400/)[0];
       debug "Found " . "$high";
    } elsif (($val =~ m/url:(.*?),bitrate:1400/)){
       $medium = ($val =~ /url:(.*?),bitrate:1400/)[0];
       debug "Found " . "$medium";
    }elsif (($val =~ m/url:(.*?),bitrate:850/)){
       $low = ($val =~ /url:(.*?),bitrate:850/)[0];
       debug "Found " . "$low";
    }elsif(($val =~ m/url:(.*?),bitrate:320/)){
       $ultralow = ($val =~ /url:(.*?),bitrate:320/)[0];
       debug "Found " . "$ultralow";
    }
  }

  my $encode_rate = $encode_rates->{$prefs->{quality}};
  if ($encode_rate == 2400 && defined $high) {
    $url = $high;
  } elsif ($encode_rate == 1400 && defined $medium) {
    $url = $medium;
  } elsif ($encode_rate == 850 && defined $low) {
    $url = $low;
  } elsif ($encode_rate == 320 && defined $ultralow) {
    $url = $ultralow;
  } elsif (defined $high){
    $url = $high;
    debug "Using high"
  } elsif (defined $medium) {
    $url = $medium;
    debug "Using medium"
  } elsif (defined $low) {
    $url = $low;
    debug "Using low"
  } elsif (defined $ultralow) {
    $url = $ultralow;
    debug "Using ultralow"
  }
  
  info "Using rtmp-url: $url";
  my $sub = ($browser->content =~ /subtitle=(.*?)&/)[0];
  my $videoid = ($browser->content =~ /videoId:'(.*?)'}/)[0];
  debug "videoid:$videoid";
  $browser->get("http://svtplay.se/popup/lasmer/v/" . "$videoid");
  my $title = ($browser->content =~ /property="og:title" content="(.*?)" \/>/)[0];
  my $flv_filename = title_to_filename($title, "flv");

  if ($prefs->{subtitles} == 1) {
    if ($sub) {
      info "Found subtitles: $sub";
      $browser->get("$sub");
      my $srt_filename = title_to_filename($title, "srt"); 
      my $srt_content = $browser->content;
      open (SRT, '>>',$srt_filename) 
        or die "Can't open subtitles file $srt_filename: $!";
      binmode SRT, ':utf8';
      print SRT $srt_content;
      close SRT;
    } else {
      info "No subtitles found!";
    }
  }
  return{
      rtmp => "$url",
      flv => "$flv_filename",
  };


}

1;
