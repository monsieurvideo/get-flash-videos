# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Vitheque;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;
  my ($filename, $playpath, $param, $rtmp);

  debug "Vitheque::find_video called, embed_url = \"$embed_url\"\n";
  for my $param($browser->content =~ /(?si)<embed.*?flashvars=["']?([^"'>]+)/gi) {
    if($param =~ m{file=([^ &"']+)}) {
        debug "playpath: ($1)";
        $playpath = $1;
    }
    if($param =~ m{(rtmp://[^ &"']+)}) {
        debug "rtmp: $1";
        $rtmp = $1;
    }
  }
  if($browser->content =~ /<span id="dnn_ctr1641_ViewVIT_FicheTitre_ltlTitre">(.*?)<\/span>/gi) {
	$filename = title_to_filename($1);
  } else {
      $filename = title_to_filename(File::Basename::basename($playpath));
  }
  return {
      rtmp => $rtmp,
      playpath => "mp4:$playpath",
      flv => $filename,
      swfVfy => "http://www.vitheque.com/DesktopModules/VIT_FicheTitre/longTail/player-licensed.swf"
  };
}

1;
