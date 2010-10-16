# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Brightcove;

use strict;
use FlashVideo::Utils;
use MIME::Base64;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my $metadata = { };
  my ($video_id, $player_id);

  # URL params, JSON, etc..
  $video_id  = ($browser->content =~ /(?:clip|video)Id["'\] ]*[:=]["' ]*(\d+)/i)[0];
  $player_id = ($browser->content =~ /playerId["'\] ]*[:=]["' ]*(\d+)/i)[0];

  # <object> params
  $player_id ||= ($browser->content =~ /<param name=["']?playerID["']? value=["'](\d+) ?["']/i)[0];
  $video_id ||= ($browser->content =~ /<param name=["']?\@?video(?:Player|id)["']? value=["'](\d+)["']/i)[0];

  # flashVar params (e.g. <embed>)
  $player_id ||= ($browser->content =~ /flashVars.*playerID=(\d+)/i)[0];
  $video_id ||= ($browser->content =~ /flashVars.*video(?:Player|ID)=(\d+)/i)[0];

  # Brightcove JavaScript API
  if(!$player_id && $browser->content =~ /brightcove.player.create\(['"]?(\d+)['"]?,\s*['"]?(\d+)/) {
    $video_id = $1;
    $player_id = $2;
  }

  # Support direct links to videos
  for my $url($browser->uri->as_string, $embed_url) {
    if($url =~ /(?:videoID|bctid)=?(\d+)/i) {
      $video_id ||= $1;
    }

    if($url =~ /(?:playerID|bcpid)=?(\d+)/i) {
      $player_id ||= $1;
    }

    if($url =~ /(?:lineupID|bclid)=?(\d+)/i) {
      $metadata->{lineupId} ||= $1;
    }
  }

  debug "Extracted playerId: $player_id, videoId: $video_id, lineupID: $metadata->{lineupId}"
    if $player_id or $video_id;

  die "Unable to extract Brightcove IDs from page" unless $player_id;

  $metadata->{videoId} = $video_id;# unless $metadata->{lineupId};
  return $self->amfgateway($browser, $player_id, $metadata);
}

sub amfgateway {
  my($self, $browser, $player_id, $metadata) = @_;

  my $has_amf_packet = eval { require Data::AMF::Packet };
  if (!$has_amf_packet) {
    die "Must have Data::AMF::Packet installed to download Brightcove videos";
  }

  my $page_url = $browser->uri;

  my $packet = Data::AMF::Packet->deserialize(decode_base64(<<EOF));
AAAAAAABAEhjb20uYnJpZ2h0Y292ZS50ZW1wbGF0aW5nLlRlbXBsYXRpbmdGYWNhZGUuZ2V0Q29u
dGVudEZvclRlbXBsYXRlSW5zdGFuY2UAAi8yAAACNQoAAAACAEH4tP+1EAAAEAA1Y29tLmJyaWdo
dGNvdmUudGVtcGxhdGluZy5Db250ZW50UmVxdWVzdENvbmZpZ3VyYXRpb24ACnZpZGVvUmVmSWQG
AAd2aWRlb0lkBgAIbGluZXVwSWQGAAtsaW5ldXBSZWZJZAYAF29wdGltaXplRmVhdHVyZWRDb250
ZW50AQEAF2ZlYXR1cmVkTGluZXVwRmV0Y2hJbmZvEAAkY29tLmJyaWdodGNvdmUucGVyc2lzdGVu
Y2UuRmV0Y2hJbmZvAApjaGlsZExpbWl0AEBZAAAAAAAAAA5mZXRjaExldmVsRW51bQBAEAAAAAAA
AAALY29udGVudFR5cGUCAAtWaWRlb0xpbmV1cAAACQAKZmV0Y2hJbmZvcwoAAAACEAAkY29tLmJy
aWdodGNvdmUucGVyc2lzdGVuY2UuRmV0Y2hJbmZvAApjaGlsZExpbWl0AEBZAAAAAAAAAA5mZXRj
aExldmVsRW51bQA/8AAAAAAAAAALY29udGVudFR5cGUCAAtWaWRlb0xpbmV1cAAACRAAJGNvbS5i
cmlnaHRjb3ZlLnBlcnNpc3RlbmNlLkZldGNoSW5mbwAKY2hpbGRMaW1pdABAWQAAAAAAAAAPZ3Jh
bmRjaGlsZExpbWl0AEBZAAAAAAAAAA5mZXRjaExldmVsRW51bQBACAAAAAAAAAALY29udGVudFR5
cGUCAA9WaWRlb0xpbmV1cExpc3QAAAkAAAk=
EOF

  if (defined $player_id) {
    $packet->messages->[0]->{value}->[0] = "$player_id";
  }

  if (ref $metadata) {
    for(keys %$metadata) {
      $packet->messages->[0]->{value}->[1]->{$_} = "$metadata->{$_}";
    }
  }

  my $data = $packet->serialize;

  $browser->post(
    "http://c.brightcove.com/services/amfgateway",
    Content_Type => "application/x-amf",
    Content => $data
  );

  die "Failed to post to Brightcove AMF gateway"
    unless $browser->response->is_success;

  $packet = Data::AMF::Packet->deserialize($browser->content);

  if($::opt{debug}) {
    require Data::Dumper;
    debug Data::Dumper::Dumper($packet);
  }

  if(ref $packet->messages->[0]->{value} ne 'ARRAY') {
    die "Unexpected data from AMF gateway";
  }

  my @found;
  for (@{$packet->messages->[0]->{value}}) {
    if ($_->{data}->{videoDTO}) {
      push @found, $_->{data}->{videoDTO};
    }
    if ($_->{data}->{videoDTOs}) {
      push @found, @{$_->{data}->{videoDTOs}};
    }
  }

  my @rtmpdump_commands;

  for my $d (@found) {
    next if $metadata->{videoId} && $d->{id} != $metadata->{videoId};

    my $host = ($d->{FLVFullLengthURL} =~ m!rtmp://(.*?)/!)[0];
    my $file = ($d->{FLVFullLengthURL} =~ m!&([a-z0-9:]+/.*?)(?:&|$)!)[0];
    my $app = ($d->{FLVFullLengthURL} =~ m!//.*?/(.*?)/&!)[0];
    my $filename = ($d->{FLVFullLengthURL} =~ m!&.*?/([^/&]+)(?:&|$)!)[0];

    $app .= "?videoId=$d->{id}&lineUpId=$d->{lineupId}&pubId=$d->{publisherId}&playerId=$player_id&playerTag=&affiliateId=";

    my $args = {
      app => $app,
      pageUrl => $page_url,
      swfUrl => "http://admin.brightcove.com/viewer/federated/f_012.swf?bn=590&pubId=$d->{publisherId}",
      tcUrl => "rtmp://$host:1935/$app",
      auth => ($d->{FLVFullLengthURL} =~ /^[^&]+&(.*)$/)[0],
      rtmp => "rtmp://$host/$app",
      playpath => $file,
      flv => "$filename.flv",
    };

    # Use sane filename
    if ($d->{publisherName} and $d->{displayName}) {
      $args->{flv} = title_to_filename("$d->{publisherName} - $d->{displayName}");
    }

    # In some cases, Brightcove doesn't use RTMP streaming - the file is
    # downloaded via HTTP.
    if (!$d->{FLVFullLengthStreamed}) {
      info "Brightcove HTTP download detected";
      return ($d->{FLVFullLengthURL}, $args->{flv});
    }

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

  return 1 if $url && URI->new($url)->host =~ /\.brightcove\.com$/;

  return $browser->content =~ /(playerI[dD]|brightcove.player.create)/
    && $browser->content =~ /brightcove/i;
}

1;
