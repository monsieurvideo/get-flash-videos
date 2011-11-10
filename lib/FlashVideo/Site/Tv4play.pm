# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Tv4play;
use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;
  my $vid = ($embed_url =~ /videoid=([0-9]*)/)[0];
  my $smi_url = "http://premium.tv4play.se/api/web/asset/$vid/play";
 
  my $title = ($browser->content =~ /property="og:title" content="(.*?)"/)[0];
  my $flv_filename = title_to_filename($title, "flv");

  $browser->get($smi_url);
  my $content = from_xml($browser);
  my $i = 0;
  my @dump;
  my $subtitle_url;
  for ($i = 0; $i < 5; $i++){
    my $format = $content->{items}->{item}[$i]->{mediaFormat};
    my $bitrate = $content->{items}->{item}[$i]->{bitrate};
    my $rtmp = $content->{items}->{item}[$i]->{base};
    my $mp4 = $content->{items}->{item}[$i]->{url};
    @dump[$i] = { 'rtmp' => $rtmp,
		  'bitrate' => $bitrate,
		  'mp4' => $mp4,
		  'format' => $format
		};
  }  
  foreach (@dump) {
    if($_->{format} eq 'smi'){ $subtitle_url = $_->{mp4};}
  }
  debug "Subtitle_url: $subtitle_url";
  # Subtitle not supported
  # if ($prefs->{subtitles} == 1) {
  #   if (not $subtitle_url eq '') {
  #     info "Found subtitles: $subtitle_url";
  #     $browser->get("$subtitle_url");
  #     my $srt_filename = title_to_filename($title, "srt"); 
  #     if(!eval { require XML::Simple && XML::Simple::XMLin("<foo/>") }) {
  # 	die "Must have XML::Simple to download " . caller =~ /::([^:])+$/ . " videos\n";
  #     }
  #     convert_sami_subtitles_to_srt($browser->content, $srt_filename);
  #   } else {
  #     info "No subtitles found!";
  #   }
  # }

  my @rtmpdump_commands; 
  my $args = {
      rtmp => $dump[0]->{rtmp},
      swfVfy => "http://www.tv4play.se/flash/tv4playflashlets.swf",
      playpath =>  $dump[0]->{mp4},
      flv => $flv_filename
  };
  push @rtmpdump_commands, $args;
  return \@rtmpdump_commands;
}

1;
