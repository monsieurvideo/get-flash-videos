# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Kanal5play;

use strict;
use FlashVideo::Utils;

my $widths = {
     "low" => 480,
     "medium" => 640, 
     "high" => 1024 };

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;
  my $has_amf_conn = eval { require AMF::Connection };
  if (!$has_amf_conn) {
    die "Must have AMF::Connection installed";
  }
  my $player_id = "811317479001";
  my $video_id = ($browser->content =~ /videoPlayer" value="(.*?)"/)[0];
  if ($video_id eq ''){die "Could not find video_id";}
  info "found video_id: $video_id";
  debug "$prefs->{quality}";
  my @dump = $self->amfgateway($browser, $player_id, $video_id,$prefs);

  my $width = 0;
  my $rtmp;
  my $playpath;
  my $new_width;

  foreach (@dump) {
    $new_width = int($_->{width});
    if(($new_width > $width) and (($widths->{$prefs->{quality}}) >= $new_width)){
        $width = int($_->{width});
        $rtmp = $_->{rtmp};
        $playpath = $_->{mp4};
    }
  };

  my @rtmpdump_commands;
  my $title = ($browser->content =~ /property="og:title" content="(.*?)"/)[0];
  my $flv_filename = title_to_filename($title, "flv");
  my $args = {
      rtmp => $rtmp,
      swfVfy => "http://admin.brightcove.com/viewer/us1.25.04.01.2011-05-24182704/connection/ExternalConnection_2.swf",
      playpath => $playpath,
      flv => $flv_filename
  };
  push @rtmpdump_commands, $args;
  return \@rtmpdump_commands;
}

sub amfgateway {
  my($self, $browser, $player_id, $videoId, $prefs) = @_;

  my $endpoint = 'http://c.brightcove.com/services/amfgateway';
  my $service = 'com.brightcove.templating.TemplatingFacade';
  my $method = 'getContentForTemplateInstance';
  my $client = new AMF::Connection( $endpoint );
  my $params = [
		$player_id,	# param 1 - playerId
		{
		 'fetchInfos' => [
				  {
				   'fetchLevelEnum' => '1',
				   'contentType' => 'VideoLineup',
				   'childLimit' => '100'
				  },
				  {
				   'fetchLevelEnum' => '3',
				   'contentType' => 'VideoLineupList',
				   'grandchildLimit' => '100',
				   'childLimit' => '100'
				  }
				 ],
		 'optimizeFeaturedContent' => 1,
		 'lineupRefId' => undef,
		 'lineupId' => undef,
		 'videoRefId' => undef,
		 'videoId' => $videoId, # param 2 - videoId
		 'featuredLineupFetchInfo' => {
					       'fetchLevelEnum' => '4',
					       'contentType' => 'VideoLineup',
					       'childLimit' => '100'
					      }
		}
	       ];

  my $response = $client->call( $service.'.'.$method, $params );
  my @dump;
  if ( $response->is_success ) {
    my $count = 0;
    for ($count = 0; $count < 3; $count++){
      my $defaultURL = $response->{data}[0]->{data}->{videoDTO}->{renditions}[$count]->{defaultURL};
      my $mp4 = reverse(((reverse($defaultURL)) =~ m/(.*?)&/)[0]);
      my $width = $response->{data}[0]->{data}->{videoDTO}->{renditions}[$count]->{frameWidth};
      my $rtmp = ($defaultURL =~ m/(.*?)&/)[0];
      @dump[$count] = { 'rtmp' => $rtmp,
			'width' => $width,
			'mp4' => $mp4
		      };
      
    }
  } else {
    die "Can not send remote request for $service.$method method with params on $endpoint using AMF".$client->getEncoding()." encoding.\n";
  };
  return @dump;
}
1;
