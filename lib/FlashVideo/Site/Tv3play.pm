# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Tv3play;
use strict;
use FlashVideo::Utils;


sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;
  return $self->find_video_viasat($browser,$embed_url,$prefs);
}

sub find_video_viasat {
  my ($self, $browser, $embed_url, $prefs) = @_;
  my $video_id = ($browser->content =~ /id:([0-9]*),/)[0];
  info "Got video_id: $video_id";
  my $info_url = "http://viastream.viasat.tv/PlayProduct/$video_id";
  $browser->get($info_url);
  my $variable = $browser->content;
  $variable =~ s/\n//g;
  my $title = ($variable =~ /<Title><!\[CDATA\[(.*?)\]\]><\/Title>/)[0];
  my $flv_filename = title_to_filename($title, "flv");

  # Subtitle Format not supported

  # my $subtitle_url = ($variable =~ /<SamiFile>(.*)<\/SamiFile>/)[0];
  # debug "Subtitle_url: $subtitle_url";
  # if ($prefs->{subtitles} == 1) {
  #   if (not $subtitle_url eq '') {
  #     info "Found subtitles: $subtitle_url";
  #     $browser->get("$subtitle_url");
  #     my $srt_filename = title_to_filename($title, "srt"); 
  #     convert_sami_subtitles_to_srt($browser->content, $srt_filename);
  #   } else {
  #     info "No subtitles found!";
  #   }
  # }

  my @urls;
  my $count = 0;
  my $base = ($variable =~ /<Videos>(.*)<\/Videos>/)[0];
  for ($count = 0; $count < 3; $count++){
    my $video = ($base =~ /<Video>(.+)<\/Video>/p)[0];
    if ($video eq ''){last;};
    $base = ${^POSTMATCH};    
    my $bitrate = ($video =~ /<BitRate>([0-9]*)<\/BitRate>/)[0];
    my $url = ($video =~ /<Url><!\[CDATA\[(.*)]]><\/Url>/)[0];
    if (not (($url =~ /http:\/\//)[0] eq '')){
      $browser->get($url);
      $variable = $browser->content;
      $variable =~ s/\n//g;
      $url = ($variable =~ /<Url>(.*)<\/Url>/)[0];
    }
    
    $urls[$count++] = { 'bitrate' => $bitrate,
		      'rtmp' => $url
		    };
  }
  my $bitrate = 0;
  my $rtmp;
  my $new_bitrate;

  foreach (@urls) {
    $new_bitrate = int($_->{bitrate});
    if($new_bitrate > $bitrate){
        $bitrate = int($_->{bitrate});
        $rtmp = $_->{rtmp};
    }
  };


  return{
      rtmp => $rtmp,
      swfVfy => "http://flvplayer-viastream-viasat-tv.origin.vss.viasat.tv/play/swf/player110420.swf",
      flv => $flv_filename
  };


}

1;
