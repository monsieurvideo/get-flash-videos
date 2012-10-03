# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Channel5;

use strict;
use FlashVideo::Utils;
use MIME::Base64;

my $encode_rates = {
     "low" => 480,
     "medium" => 800,
     "medium2" => 1200, 
     "high" => 1500 };

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;

  my $metadata = { };
  my ($video_id, $player_id);

  # URL params, JSON, etc..
  $player_id = ($browser->content =~ /playerId["'\] ]*[:=]["' ]*(\d+)/i)[0];
  $metadata->{videoplayer} = ($browser->content =~ /videoPlayer=ref:(C\d+)/i)[0];
  $metadata->{publisherId} = ($browser->content =~ /publisherID=(\d+)/i)[0];

  # <object> params
  $player_id ||= ($browser->content =~ /<param name=["']?playerID["']? value=["'](\d+) ?["']/i)[0];
  $metadata->{videoplayer} ||= ($browser->content =~ /param name=["']?\@videoPlayer["']? value=["']?(\d+)["']?/i)[0];
  $metadata->{publisherId} ||= ($browser->content =~ /param name=["']?publisherID["']? value=["']?(\d+)["']?/i)[0];

  # flashVar params (e.g. <embed>)
  $player_id ||= ($browser->content =~ /flashVars.*playerID=(\d+)/i)[0];

  # Brightcove JavaScript API
  if(!$player_id && $browser->content =~ /brightcove.player.create\(['"]?(\d+)['"]?,\s*['"]?(\d+)/) {
    $player_id = $2;
  }

  $metadata->{sessionId} = ($browser->cookie_jar->as_string =~ /session=([0-9a-f]*);/)[0];

  # Support direct links to videos
  for my $url($browser->uri->as_string, $embed_url) {

    if($url =~ /(?:playerID|bcpid)=?(\d+)/i) {
      $player_id ||= $1;
    }
  }

# from script
# <script src="http//wwwcdn.channel5.com/javascript/all.js?"
# playerID is set to 1707001746001 by default or 1707001743001 for firefox
# 138489951601 for MSIE.
  $player_id ||= "1707001743001";

  debug "Extracted playerId: $player_id, sessionId: $metadata->{sessionId} videoplayer: $metadata->{videoplayer} publisherId: $metadata->{publisherId} "
    if $player_id or $video_id;

  die "Unable to extract Brightcove IDs from page" unless $player_id;

  return $self->amfgateway($browser, $player_id, $metadata, $prefs);
}

sub amfgateway {
  my($self, $browser, $player_id, $metadata, $prefs) = @_;

  my $has_amf_packet = eval { require Data::AMF::Packet };
  if (!$has_amf_packet) {
    die "Must have Data::AMF::Packet installed to download Brightcove videos";
  }

  my $page_url = $browser->uri;
  my $base_url = "" . $page_url;

#  AMF3 incompatable between Data::AMF and Brightcove
#  results in Brightcove rejecting message 
#  create message without deserialize/serialize.

  my $amf0_formatter = Data::AMF::Formatter->new(version =>0);
  my $amf3_formatter = Data::AMF::Formatter->new(version =>3);
  my @amf_pkt;


  $amf_pkt[0] = decode_base64(<<EOF1);
AAMAAAABAEZjb20uYnJpZ2h0Y292ZS5leHBlcmllbmNlLkV4cGVyaWVuY2VSdW50aW1lRmFjYWRl
LmdldERhdGFGb3JFeHBlcmllbmNlAAIvMQAA
EOF1

  $amf_pkt[2] = decode_base64(<<EOF2);
CgAAAAI=
EOF2

  $amf_pkt[3] = $amf0_formatter->format($metadata->{sessionId});

  $amf_pkt[4] = decode_base64(<<EOF3);
EQpjY2NvbS5icmlnaHRjb3ZlLmV4cGVyaWVuY2UuVmlld2VyRXhwZXJpZW5jZVJlcXVlc3QhY29u
dGVudE92ZXJyaWRlcwdVUkwZZXhwZXJpZW5jZUlkEVRUTFRva2VuE3BsYXllcktleRlkZWxpdmVy
eVR5cGUJAwEKgQNTY29tLmJyaWdodGNvdmUuZXhwZXJpZW5jZS5Db250ZW50T3ZlcnJpZGUXY29u
dGVudFR5cGUTY29udGVudElkGWNvbnRlbnRSZWZJZBtmZWF0dXJlZFJlZklkG2NvbnRlbnRSZWZJ
ZHMVZmVhdHVyZWRJZBVjb250ZW50SWRzDXRhcmdldAQABX/////gAAAA
EOF3

  $amf_pkt[5] = $amf3_formatter->format($metadata->{videoplayer});

  $amf_pkt[6] = decode_base64(<<EOF4);
AQEFf////+AAAAABBhd2aWRlb1BsYXllcg==
EOF4

  $amf_pkt[7] = $amf3_formatter->format($base_url);

  $amf_pkt[8] = decode_base64(<<EOF5);
BUI4gZvSwQAABgEGAQV/////4AAAAA==
EOF5
  my $experianceid = $amf3_formatter->format($player_id);
  $amf_pkt[8] = $experianceid . substr($amf_pkt[8], 7);


  $amf_pkt[1] = pack('n', length(join('',@amf_pkt[2..8])));

  my $data = join('',@amf_pkt[0..8]);

#   my $packet = Data::AMF::Packet->deserialize($data);

#  if (defined $player_id) {
#    $packet->messages->[0]->{value}->[0] = "$player_id";
#  }

#  if (ref $metadata) {
#    for(keys %$metadata) {
#      $packet->messages->[0]->{value}->[1]->{$_} = "$metadata->{$_}";
#    }
#  }

#   my $data = $packet->serialize;

  $browser->post(
    "http://c.brightcove.com/services/messagebroker/amf?playerid=$player_id",
    Content_Type => "application/x-amf",
    Content => $data
  );

  die "Failed to post to Brightcove AMF gateway"
    unless $browser->response->is_success;

  my $packet = Data::AMF::Packet->deserialize($browser->content);

  if($self->debug) {
    require Data::Dumper;
#    my $data1 = Data::AMF::Packet->deserialize($data);
#    debug Data::Dumper::Dumper($data1);
    debug Data::Dumper::Dumper($packet);
  }

# renditions Array contains the rtmpe URL.
  if ( ref  $packet->messages->[0]->{value}->{programmedContent}->{videoPlayer}->{mediaDTO}->{renditions} ne 'ARRAY') {
    die "Unexpected data from AMF gateway";
  }

  my @found;
  for (@{$packet->messages->[0]->{value}->{programmedContent}->{videoPlayer}->{mediaDTO}->{renditions}}) {
    if ($_->{defaultURL}) {
      push @found, $_;
    }
  }

# other information returned in message.
  my $mediaId = $packet->messages->[0]->{value}->{programmedContent}->{videoPlayer}->{mediaId};
  my $seasonnumber = $packet->messages->[0]->{value}->{programmedContent}->{videoPlayer}->{mediaDTO}->{customFields}->{seasonnumber};
  my $episodenumber = $packet->messages->[0]->{value}->{programmedContent}->{videoPlayer}->{mediaDTO}->{customFields}->{episodenumber};
  my $show = ($page_url =~ m!/shows/([^/]+)/!i)[0];
  my $episode = ($page_url =~ m!/episodes/([^/]+)!i)[0];
  my $filehead = sprintf("%s_S%02d", $show, $seasonnumber);
  if ( $show ne $episode ) {
    $filehead = sprintf("%s_S%02dE%02d_%s", $show, $seasonnumber, $episodenumber, $episode);
  }
  my $encode_rate = $encode_rates->{$prefs->{quality}};
  if (! defined $encode_rate ) {
    $encode_rate = $prefs->{quality};
  }

  my @rtmpdump_commands;

  for my $d (@found) {

    my $rate = ($d->{defaultURL} =~ /H264-(\d+)-16x9/i)[0];
    next if $encode_rate != $rate;
    my $host = ($d->{defaultURL} =~ m!rtmpe://(.*?)/!)[0];
    my $file = ($d->{defaultURL} =~ /^[^&]+&(.*)$/)[0];
    my $app = ($d->{defaultURL} =~ m!//.*?/(.*?)/&!)[0];
    my $filename = $filehead . "_" . $rate;

    $app .= "?videoId=$mediaId&lineUpId=&pubId=$metadata->{publisherId}&playerId=$player_id&affiliateId=";

    my $args = {
      app => $app,
      pageUrl => $page_url,
      swfVfy => "http://admin.brightcove.com/viewer/us1.24.04.08.2011-01-14072625/connection/ExternalConnection_2.swf",
      tcUrl => "rtmpe://$host:1935/$app",
      rtmp => "$d->{defaultURL}",
      playpath => $file,
      flv => "$filename.flv",
    };

    # Use sane filename
    if ($d->{publisherName} and $d->{displayName}) {
      $args->{flv} = title_to_filename("$d->{publisherName} - $d->{displayName}");
    }

    # In some cases, Brightcove doesn't use RTMP streaming - the file is
    # downloaded via HTTP.
#    if (!$d->{FLVFullLengthStreamed}) {
#      info "Brightcove HTTP download detected";
#      return ($d->{}, $args->{flv});
#    }

    push @rtmpdump_commands, $args;
  }

  if (@rtmpdump_commands > 1) {
    return \@rtmpdump_commands;
  }
  else {
    return $rtmpdump_commands[-1];
  }
}

sub can_handle {
  my($self, $browser, $url) = @_;

  return 1 if $url && URI->new($url)->host =~ /\.channel5\.com$/;

  return $browser->content =~ /(playerI[dD]|brightcove.player.create)/
    && $browser->content =~ /brightcove/i;
}

1;
