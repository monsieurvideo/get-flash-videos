# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Tvnz;

use strict;

use FlashVideo::Utils;
use URI;

my $encode_rates = {
  "low" => 250000,
  "medium" => 700000,
  "high" => 1500000
 };

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;

  my $videoPlayer = ($browser->content =~ m/\<param\s+value=\"ref:(\d+)\"\s+name=\"\@videoPlayer\"\s*\/\>/s)[0];
  my $player_id = ($browser->content =~ /\<param value=\"(\d+)\" name=\"playerID\" \/\>/i)[0];

  debug "Extracted playerId: $player_id, videoPlayer: $videoPlayer"
    if $player_id or $videoPlayer;

  my $metadata = {
    videoplayer => $videoPlayer
  };

  # The "session ID" appears to be constant.
  my $sessionId = "f86d6617a68b38ee0f400e1f4dc603d6e3b4e4ed";
  $metadata->{sessionId} = $sessionId;

  debug "Extracted playerId: $player_id, sessionId: $metadata->{sessionId} videoplayer: $videoPlayer"
    if $player_id or $videoPlayer;

  die "Unable to extract Brightcove IDs from page"
    unless $player_id && $videoPlayer && $sessionId;

  return $self->amfgateway($browser, $player_id, $metadata, $prefs);
}

sub amfrequest($$$$) {
  my($self, $base_url, $player_id, $metadata) = @_;

  my $has_amf_packet = eval { require Data::AMF::Packet };
  if (!$has_amf_packet) {
    die "Must have Data::AMF::Packet installed to download Brightcove videos";
  }

#  AMF3 incompatable between Data::AMF and Brightcove
#  results in Brightcove rejecting message 
#  create message without deserialize/serialize.

  my $amf0_formatter = Data::AMF::Formatter->new(version =>0);
  my $amf3_formatter = Data::AMF::Formatter->new(version =>3);

  my @amf_pkt = ();

  push(@amf_pkt, pack("H*", "0003000000010046636f6d2e627269676874636f76652e657870657269656e63652e457870657269656e636552756e74696d654661636164652e67657444617461466f72457870657269656e636500022f310000"));

  push(@amf_pkt, "");
  my $lengthIndex = $#amf_pkt;

  push(@amf_pkt, pack("H*", "0a00000002"));

  push(@amf_pkt, $amf0_formatter->format($metadata->{sessionId}));

  push(@amf_pkt, pack("H*", "110a6363636f6d2e627269676874636f76652e657870657269656e63652e566965776572457870657269656e63655265717565737413706c617965724b657921636f6e74656e744f76657272696465731154544c546f6b656e1964656c6976657279547970650755524c19657870657269656e6365496406010903010a810353636f6d2e627269676874636f76652e657870657269656e63652e436f6e74656e744f76657272696465156665617475726564496413636f6e74656e7449641b6665617475726564526566496415636f6e74656e7449647319636f6e74656e74526566496417636f6e74656e74547970651b636f6e74656e745265664964730d746172676574057fffffffe0000000057fffffffe00000000101"));

  sub amf3_string($$) {
    my $self = $_[0]->new;
    $self->io->write_u8($self->STRING_MARKER);
    $self->write_string($_[1]);
    return $self->io->data;
  }

  push(@amf_pkt, amf3_string($amf3_formatter, $metadata->{videoplayer}));

  push(@amf_pkt,
       pack("H*","0400010617766964656f506c617965720601057fffffffe0000000"));

  push(@amf_pkt, amf3_string($amf3_formatter, $base_url));

  push(@amf_pkt, $amf3_formatter->format($player_id));

  $amf_pkt[$lengthIndex] = pack('n', length(
    join('',@amf_pkt[$lengthIndex .. $#amf_pkt])));

  return join('', @amf_pkt);
}

sub amfresponse($$$$$$) {
  my ($self, $page_url, $player_id, $metadata, $prefs, $content) = @_;

  my $packet = Data::AMF::Packet->deserialize($content);

  if ($self->debug) {
    require Data::Dumper;
    debug Data::Dumper::Dumper($packet);
  }

  #require Data::Dumper;
  #print Data::Dumper::Dumper($packet);

  # renditions Array contains the rtmpe URL.
  my $renditions = $packet->messages->[0]->{value}->{programmedContent}->{videoPlayer}->{mediaDTO}->{renditions};
  if (ref($renditions) ne 'ARRAY') {
    die "Unexpected data from AMF gateway";
  }

  # other information returned in message.
  my $detail = $packet->messages->[0]->{value}->{programmedContent}->{videoPlayer};

  my $mediaId = $detail->{mediaId};

  my $mediaDTO = $detail->{mediaDTO};

  my $publisherId = $mediaDTO->{publisherId};
  die "Publisher ID not determined" if !defined($publisherId);

  my $customFields = $mediaDTO->{customFields};

  my $programme = $customFields->{programme};
  if (!defined($programme)) {
    # Fall back onto the display name if the video doesn't have
    # programme/series/episode details (For example, a clip).
    $programme = $mediaDTO->{displayName};
  }
  die "Programme name not determined" if !defined($programme);

  my $seriesnumber = $customFields->{seriesnumber};
  my $episodenumber = $customFields->{episodenumber};

  if (defined($seriesnumber) || defined($episodenumber)) {
    $programme .= "_";
    $programme .= sprintf("S\%02d", $seriesnumber) if defined($seriesnumber);
    $programme .= sprintf("E\%02d", $episodenumber) if defined($episodenumber);
  }

  my $episodename = $customFields->{episodename};
  $programme .= "_" . $episodename if defined($episodename);

  my $encode_rate = $encode_rates->{$prefs->{quality}};
  if (!defined($encode_rate)) {
    $encode_rate = $prefs->{quality};
  }

  my $bestMatch = undef;
  foreach my $rendition (@{$renditions}) {
    my $defaultURL = $rendition->{defaultURL};
    next if !defined($defaultURL);

    my $rate = $rendition->{encodingRate};

    # The service returns encoding rates that are close to, but not
    # exactly, the published rates of 250k, 700k, 1500k etc.  For
    # example, 1499998 instead 1500k.  Round the rate to the nearest
    # 1k.
    {
      use integer;
      $rate = (($rate + 500) / 1000) * 1000;
    }

    #print "Saw: " . $rendition->{defaultURL} . " @ " . $rate . "\n";

    # If the selected rate is lower than this option's rate, discard
    # this option.
    next if $encode_rate < $rate;

    # If we have already found an option that is lower than the
    # selected encoding rate, but higher than this rate, then discard
    # this option.
    next if (defined($bestMatch) && $bestMatch->{rate} > $rate);

    $bestMatch = {
      rate => $rate,
      rendition => $rendition
     }
  }

  return undef if !defined($bestMatch);

  my $d = $bestMatch->{rendition};
  my $rate = $bestMatch->{rate};

  my $defaultURL = $d->{defaultURL};

  if ($defaultURL !~ m!^(rtmpe?)://([^/]+)/([^&]+)/&(.*)$!s) {
    die "Failed to parse URL: " . $defaultURL;
  }
  my $protocol = $1;
  my $host = $2;
  my $rtmpApp = $3;
  my $file = $4;

  my $filenamePrefix = $programme . "_" . $rate;

  my $filename = title_to_filename($filenamePrefix);
  $filename ||= get_video_filename();

  my $app = $rtmpApp . "?videoId=" . $mediaId .
    "&lineUpId=&pubId=" . $publisherId .
      "&playerId=" . $player_id . "&affiliateId=";

  my $port = 1935;

  #
  # Content reported with the "rtmp" protocol are actually delivered
  # on port 80 via "rtmpt".
  #
  if ($protocol eq "rtmp") {
    $port = 80;
    $protocol = "rtmpt";
  }

  my $tcUrl = $protocol . "://" . $host . ":" . $port . "/" . $rtmpApp;
  my $rtmpUrl = $protocol . "://" . $host . "/" . $rtmpApp . "/&" . $file;

  my $args = {
    app => $app,
    pageUrl => $page_url,
    swfVfy => "http://admin.brightcove.com/viewer/us1.24.04.08.2011-01-14072625/connection/ExternalConnection_2.swf",
    tcUrl => $tcUrl,
    rtmp => $rtmpUrl,
    playpath => $file,
    flv => $filename,
  };

  return [ $args ];
}

sub amfgateway {
  my($self, $browser, $player_id, $metadata, $prefs) = @_;

  my $page_url = $browser->uri;
  my $base_url = "" . $page_url;

  my $data = $self->amfrequest($base_url, $player_id, $metadata);

  $browser->post(
    "http://c.brightcove.com/services/messagebroker/amf?playerid=$player_id",
    Content_Type => "application/x-amf",
    Content => $data
   );

  die "Failed to post to Brightcove AMF gateway"
    unless $browser->response->is_success;

  my $content = $browser->content;

  #open(F, "> response.data");print F $content;close(F);

  my $commands = $self->amfresponse($page_url, $player_id, $metadata,
                                    $prefs, $content);

  if ($#$commands > 0) {
    return $commands;
  } else {
    return ${$commands}[0];
  }
}

sub can_handle {
  my($self, $browser, $url) = @_;

  return $url && URI->new($url)->host =~ m/(?:^|\.)tvnz\.co\.nz$/;
}

1;
