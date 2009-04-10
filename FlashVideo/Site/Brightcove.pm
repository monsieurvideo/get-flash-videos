# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Brightcove;

use strict;
use FlashVideo::Utils;
use MIME::Base64;

sub find_video {
  my ($self, $browser) = @_;

  my $has_amf_packet = eval { require Data::AMF::Packet };
  if (!$has_amf_packet) {
    die "Must have Data::AMF::Packet installed to download Brightcove videos";
  }

  my ($video_id, $player_id);

  $video_id  = ($browser->content =~ /videoId["'\] ]*=["' ]*(\d+)/)[0];
  $player_id = ($browser->content =~ /playerId["'\] ]*=["' ]*(\d+)/)[0];

  $player_id ||= ($browser->content =~ /<param name=["']?playerID["']? value=["'](\d+) ?["']/)[0];
  $video_id ||= ($browser->content =~ /<param name=["']?\@?videoPlayer["']? value=["'](\d+)["']/)[0];

  # Support "viral" videos
  my $current_url = $browser->uri->as_string;
  if (!$video_id and $current_url =~ /bctid=(\d+)/) {
    $video_id = $1;
  }

  if(!$player_id && $browser->content =~ /brightcove.player.create\(['"]?(\d+)['"]?,\s*['"]?(\d+)/) {
    $video_id = $1;
    $player_id = $2;
  }

  if (!$player_id) {
    die "Unable to extract Brightcove IDs from page";
  }

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

  if (defined $video_id) {
    $packet->messages->[0]->{value}->[1]->{videoId} = "$video_id";
  }

  my $data = $packet->serialize;

  $browser->post(
    "http://c.brightcove.com/services/amfgateway",
    Content_Type => "application/x-amf",
    Content => $data
  );

  die "Failed to post to Brightcove AMF gateway"
    unless $browser->response->is_success;

  my $packet = Data::AMF::Packet->deserialize($browser->content);

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
    my $host = ($d->{FLVFullLengthURL} =~ m!rtmp://(.*?)/!)[0];
    my $file = ($d->{FLVFullLengthURL} =~ m!&([a-z]+/.*?)(?:&|$)!)[0];
    my $app = ($d->{FLVFullLengthURL} =~ m!//.*?/(.*?)/&!)[0];
    my $filename = ($d->{FLVFullLengthURL} =~ m!&.*?/([^/&]+)(?:&|$)!)[0];

    my $args = {
      swfUrl => "http://admin.brightcove.com/viewer/federated/f_012.swf?bn=590&pubId=$d->{publisherId}",
      app => $app,
      tcUrl => "rtmp://$host/$app",
      auth => ($d->{FLVFullLengthURL} =~ /&([a-z]+\/.*)/)[0],
      rtmp => "rtmp://$host/$app",
      playpath => $file,
      flv => "$filename.flv"
    };

    # Use sane filename
    if ($d->{publisherName} and $d->{displayName}) {
      $args->{flv} = title_to_filename("$d->{publisherName} - $d->{displayName}");
    }

    # In some cases, Brightcove doesn't use RTMP streaming - the file is
    # downloaded via HTTP.
    if (!$d->{FLVFullLengthStreamed}) {
      print STDERR "Brightcove HTTP download detected\n";
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

  return $browser->content =~ /(playerI[dD]|brightcove.player.create)/
    && $browser->content =~ /brightcove/i;
}

1;
