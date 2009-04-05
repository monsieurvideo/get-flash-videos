package FlashVideo::URLFinder;

use strict;
use HTML::Entities;
use FlashVideo::Mechanize;
use LWP::Simple;
use Memoize;
use URI::Escape;
use MIME::Base64;

use constant MAX_REDIRECTS => 5;

use constant HAS_DATA_AMF_PACKET => eval { require Data::AMF::Packet };
use constant HAS_XML_SIMPLE      => eval { require XML::Simple };

# The main issue is getting a URL for the actual video, so we handle this
# here - a different method for each site, as well as a generic fallback
# method. Each method returns a URL, and a suggested filename.

sub site_ehow {
  my ($self, $browser) = @_;

  # Get the video ID
  my $video_id;
  if ($browser->content =~ /flashvars=(?:&quot;|'|")id=(\w+)&/) {
    $video_id = $1;
  }
  else {
    die "Couldn't extract video ID from page";
  }

  # Get the embedding page
  my $embed_url =
    "http://www.ehow.com/embedvars.aspx?isEhow=true&show_related=true&" .
    "from_url=" . uri_escape($browser->uri->as_string) .
    "&id=" . $video_id;

  my $title;
  if ($browser->content =~ /<div\ class="DetailHeader">
                            <h1\ class="SubHeader">(.*?)<\/h1>/x) {
    $title = $1;
  }

  $browser->get($embed_url);

  if ($browser->content =~ /&source=(http.*?flv)&/) {
    return (uri_unescape($1), (title_to_filename($title) ||
        get_video_filename()) );
  }
  else {
    die "Couldn't extract Flash video URL from embed page";
  }
}

sub site_brightcove {
  my ($self, $browser) = @_;

  if (!HAS_DATA_AMF_PACKET) {
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
    my $file = ($d->{FLVFullLengthURL} =~ m!&(media.*?)&!)[0];
    my $app = ($d->{FLVFullLengthURL} =~ m!//.*?/(.*?)/&!)[0];
    my $filename = ($d->{FLVFullLengthURL} =~ m!&.*?/([^/&]+)&!)[0];

    my $args = {
      swfUrl => "http://admin.brightcove.com/viewer/federated/f_012.swf?bn=590&pubId=$d->{publisherId}",
      app => "$app?videoId=$d->{videoId}&lineUpId=$d->{lineUpId}&pubId=$d->{publisherId}&playerId=$d->{playerId}",
      tcUrl => $d->{FLVFullLengthURL},
      auth => ($d->{FLVFullLengthURL} =~ /&(media.*)/)[0],
      rtmp => "rtmp://$host/?slist=$file",
      flv => "$filename.flv"
    };

    # Use sane filename
    if ($d->{publisherName} and $d->{displayName}) {
      $args->{flv} = FlashVideo::URLFinder::title_to_filename("$d->{publisherName} - $d->{displayName}");
    }

    # In some cases, Brightcove doesn't use RTMP streaming - the file is
    # downloaded via HTTP.
    if (!$d->{FLVFullLengthStreamed}) {
      print STDERR "Brightcove HTTP download detected\n";  
      return ($d->{FLVFullLengthURL}, $args->{flv});
    }

    push @rtmpdump_commands, join " ", 'rtmpdump', map { ("--$_" => "'" . $args->{$_} . "'") } keys %$args;
  }

  if (@rtmpdump_commands > 1) {
    return \@rtmpdump_commands;
  }
  else {
    return $rtmpdump_commands[-1];
  }
}

sub site_bbc {
  my ($self, $browser) = @_;

  if (!HAS_XML_SIMPLE) {
    die "Must have XML::Simple installed to download BBC videos";
  }

  # Get playlist XML
  my $playlist_xml;
  if ($browser->content =~ /<param name="playlist" value="(http:.+?\.xml)"/) {
    $playlist_xml = $1; 
  }
  else {
    die "Couldn't find BBC XML playlist URL in " . $browser->uri->as_string;
  }

  $browser->get($playlist_xml);
  if (!$browser->success) {
    die "Couldn't download BBC XML playlist $playlist_xml: " .
      $browser->status_line;
  }

  my $playlist = eval {
    XML::Simple::XMLin($browser->content)
  };

  if ($@) {
    die "Couldn't parse BBC XML playlist: $@";
  }

  my $app   = $playlist->{item}->{media}->{connection}->{application};
  my $tcurl = "rtmp://" .  $playlist->{item}->{media}->{connection}->{server} .
              "/$app";
  my $rtmp  = "rtmp://" .  $playlist->{item}->{media}->{connection}->{server} .
              "/?slist=" .  $playlist->{item}->{media}->{connection}->{identifier};
              # (Note slist is an rtmpdump weirdism)
  my $sound = ($playlist->{item}->{guidance} !~ /has no sound/);
  my $flv   = title_to_filename('BBC - ' . $playlist->{title} .
                                ($sound ? '' : ' (no sound)'));

  # 'Secure' items need to be handled differently - have to get a token to
  # pass to the rtmp server.
  my $swfurl;
  if ($playlist->{item}->{media}->{connection}->{identifier} =~ /^secure/) {
    my $info = $playlist->{item}->{media}->{connection};

    my $url = "http://www.bbc.co.uk/mediaselector/4/gtis?server=$info->{server}" .
              "&identifier=$info->{identifier}&kind=$info->{kind}" .
              "&application=$info->{application}&cb=123";

    print STDERR "Got BBC auth URL for 'secure' video: $url\n";

    $browser->get($url);

    # BBC redirects us to the original URL which is odd, but oh well.
    if (my $redirect = $browser->response->header('Location')) {
      print STDERR "BBC auth URL redirects to: $url\n";
      $browser->get($redirect);
    }

    my $stream_auth = eval {
      XML::Simple::XMLin($browser->content);
    };

    if ($@) {
      die "Couldn't parse BBC stream auth XML for 'secure' stream.\n" .
          "XML is apparently:\n" .
          $browser->content() . "\n" .
          "XML::Simple said: $@";
    }

    my $token = $stream_auth->{token};

    if (!$token) {
      die "Couldn't get token for 'secure' video download";
    }

    $app = "ondemand?_fcs_vhost=$info->{server}"
            . "&auth=$token"
            . "&aifp=v001&slist=" . $info->{identifier};
    $tcurl = "rtmp://$info->{server}:80/$app";
    $rtmp  = "rtmp://$info->{server}:1935/ondemand?_fcs_vhost="
            . $info->{server} . "&aifp=v001" .
              "&slist=" . $info->{identifier};
    $swfurl = " --swfUrl 'http://www.bbc.co.uk/emp/9player.swf?revision=7978_8340'";
  }

  return "rtmpdump -o '$flv' --app '$app' --tcUrl '$tcurl' --rtmp '$rtmp' $swfurl ";
}

sub site_youtube {
  my ($self, $browser, $url) = @_;

  if($url !~ m!/watch!) {
    $browser->get($url);
    if ($browser->response->header('Location') =~ m!/swf/.*video_id=([^&]+)!) {
      # We ended up on a embedded SWF
      $browser->get("http://www.youtube.com/watch?v=$1");
    }
  }

  if (!$browser->success) {
    if ($browser->response->code == 303) {
      # Lame age verification page - yes, we are grown up, please just give
      # us the video!
      my $confirmation_url = $browser->response->header('Location');
      print "Unfortunately, due to Youtube being lame, you have to have\n" .
            "an account to download this video.\n" .
            "Username: ";
      chomp(my $username = <STDIN>);
      print "Ok, need your password (will be displayed): ";
      chomp(my $password = <STDIN>);
      unless ($username and $password) {
        print "You must supply Youtube account details.\n";
        exit;
      }

      $browser->get("http://youtube.com/login");
      $browser->form_name("loginForm");
      $browser->set_fields(username => $username,
                           password => $password);
      $browser->submit();
      if ($browser->content =~ /your login was incorrect/) {
        print "Couldn't log you in, check your username and password.\n";
        exit;
      }
      
      $browser->get($confirmation_url);
      $browser->form_with_fields('next_url', 'action_confirm');
      $browser->field('action_confirm' => 'Confirm Birth Date');
      $browser->click_button(name => "action_confirm");

      if ($browser->response->code != 303) {
        print "Unexpected response from Youtube.\n";
        exit;
      }
      $browser->get($browser->response->header('Location'));
    }
    else {
      # Lame Youtube redirection to uk.youtube.com and so on.
      if ($browser->response->code == 302) {
        $browser->get($browser->response->header('Location'));
      }

      if (!$browser->success) {
        die "Couldn't download URL: " . $browser->response->status_line;
      }
    }
  }

  my $video_id;
  if ($browser->content =~ /var pageVideoId = '(.+?)'/) {
    $video_id = $1;
  } else {
    die "Couldn't extract video ID";
  }

  my $t; # no idea what this parameter is but it seems to be needed
  if ($browser->content =~ /['"]?t['"]?: ?['"](.+?)['"]/) {
    $t = $1;  
  } else {
    die "Couldn't extract mysterious t parameter";
  }

  my $file_functor = sub {
    my($type) = @_;

    if ($browser->content =~ /<meta name="title" content="(.+?)" ?\/? ?>/ or
        $browser->content =~ /<div id="vidTitle">\s+<span ?>(.+?)<\/span>/ or 
        $browser->content =~ /<div id="watch-vid-title">\s*<div ?>(.+?)<\/div>/) {
      return title_to_filename($1, $type);
    } else {
      # Have to make up own our filename :( 
      return get_video_filename($type);
    }
  };

  my $fetcher = sub {
    my($url, $filename) = @_;
    my $browser = $browser->clone;
    my $response = $browser->get($url);
    my $redirects = 0;
    while ( ($response->code =~ /^30\d/) and ($response->header('Location'))
             and ($redirects < MAX_REDIRECTS) ) {
      my $url = $response->header('Location');
      $response = $browser->head($url);
      if ($response->code == 200) {
        return ($url, $filename);
      }
      $redirects++;
    }
    return;
  };

  # Try HD
  my @ret = $fetcher->("http://youtube.com/get_video?fmt=22&video_id=$video_id&t=$t",
    $file_functor->("mp4"));
  return @ret if @ret;

  # Try HQ
  my @ret = $fetcher->("http://youtube.com/get_video?fmt=18&video_id=$video_id&t=$t",
    $file_functor->("mp4"));
  return @ret if @ret;

  # Otherwise get normal
  return $fetcher->("http://youtube.com/get_video?video_id=$video_id&t=$t",
    $file_functor->());
}

sub site_metacafe {
  my ($self, $browser) = @_;

  my $url;
  if ($browser->content =~ m'mediaURL=(http.+?)&') {
    $url = uri_unescape($1);
  } else {
    die "Couldn't find mediaURL parameter.";
  }

  if ($browser->content =~ m'gdaKey=(.+?)&') {
    $url .= "?__gda__=" . uri_unescape($1);
  } else {
    die "Couldn't find gdaKey parameter.";
  }

  my $filename;
  if ($browser->content =~ /<title>(.*?)<\/title>/) {
    $filename = title_to_filename($1); 
  }
  $filename ||= get_video_filename();

  return ($url, $filename);
}

sub site_5min {
  my ($self, $browser) = @_;

  my $filename;
  if ($browser->content =~ /<meta name="title" content="(.+?)"/s) {
    $filename = title_to_filename($1);
  }
  $filename ||= get_video_filename();

  my $url;
  if ($browser->content =~ m{videoID=(\d+)}) {
    my $id = $1;

    my $res = $browser->post(
      "http://www.5min.com/handlers/smartplayerhandler.ashx", {
        referrerURL => "none",
        autoStart   => "None",
        sid         => 0,
        func        => "InitializePlayer",
        overlay     => "None",
        videoID     => $id,
        isEmbed     => "false"
      }
    );
    $url = $1 if $res->content =~ /vidURL\W+([^"]+)/;
  }

  return ($url, $filename);
}

# Google Video
sub site_google {
  my ($self, $browser) = @_;

  if (!$browser->success) {
    $browser->get($browser->response->header('Location'));
    die "Couldn't download URL: " . $browser->response->status_line
      unless $browser->success;
  }

  my $url;
  if ($browser->content =~ /googleplayer\.swf\?&?videoUrl=(.+?)["']/) {
    $url = uri_unescape($1);

    # Contains JavaScript (presumably) escaping \xHEX, so unescape hackily
    $url =~ s/\\x([A-F0-9]{2})/chr(hex $1)/eg;
  }

  my $filename;
  if ($browser->content =~ /<title>(.*?)<\/title>/) {
    $filename = title_to_filename($1);
  }
  $filename ||= get_video_filename();

  return ($url, $filename);
}

sub site_fliqz {
  my ($self, $browser, $url) = @_;

  $browser->content =~ /\Q$url\E.*?([a-f0-9]{32})/;
  my $id = $1;

  $browser->post("http://services.fliqz.com/mediaassetcomponentservice/20071201/service.svc",
    Content_Type => "text/xml; charset=utf-8",
    SOAPAction   => '"urn:fliqz.s.mac.20071201/IMediaAssetComponentService/ad"',
    Referer      => $url,
    Content      => <<EOF);
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<SOAP-ENV:Body>
  <i0:ad xmlns:i0="urn:fliqz.s.mac.20071201">
  <i0:rq>
    <i0:a>$id</i0:a>
    <i0:pu></i0:pu>
    <i0:pid>1F866AF1-1DB0-4864-BCA1-6236377B518F</i0:pid>
  </i0:rq>
</i0:ad> 
</SOAP-ENV:Body>
</SOAP-ENV:Envelope>
EOF

  my $flv_url  = ($browser->content =~ />(http:[^<]+\.flv)</)[0];

  my $filename = ($browser->content =~ /<t [^>]+>([^<]+)/)[0];
  $filename = title_to_filename($filename);

  # I want to follow redirects now.
  $browser->allow_redirects;

  return $flv_url, $filename;
}

sub site_nicovideo {
  my ($self, $browser, $url) = @_;
  my $id = ($url =~ /(sm\d+)/)[0];
  die "No ID found\n" unless $id;

  my $base = "http://ext.nicovideo.jp/thumb_watch/$id";

  if($url !~ /ext\.nicovideo\.jp\/thumb_watch/) {
    $url = "$base?w=472&h=374&n=1";
  }

  $browser->get($url);
  my $playkey = ($browser->content =~ /thumbPlayKey: '([^']+)/)[0];
  die "No playkey found\n" unless $playkey;

  my $title = ($browser->content =~ /title: '([^']+)'/)[0];
  $title =~ s/\\u([a-f0-9]{1,5})/chr hex $1/eg;

  $browser->get($base . "/$playkey");
  my $url = uri_unescape(($browser->content =~ /url=([^&]+)/)[0]);

  return $url, title_to_filename($title);
}

sub site_vimeo {
  my ($self, $browser, $url) = @_;
  my $base = "http://vimeo.com/moogaloop";

  if(!HAS_XML_SIMPLE) {
    die "Must have XML::Simple installed to download Vimeo videos";
  }

  my $id;
  if($url =~ /clip_id=(\d+)/) {
    $id = $1;
  } elsif($url =~ m!/(\d+)!) {
    $id = $1;
  }
  die "No ID found\n" unless $id;

  $browser->get("$base/load/clip:$id/embed?param_fullscreen=1&param_clip_id=$id&param_show_byline=0&param_server=vimeo.com&param_color=cc6600&param_show_portrait=0&param_show_title=1");

  my $xml = eval {
    XML::Simple::XMLin($browser->content)
  };

  if ($@) {
    die "Couldn't parse Vimeo XML : $@";
  }

  my $filename = title_to_filename($xml->{video}->{caption}) || get_video_filename();
  my $request_signature = $xml->{request_signature};
  my $request_signature_expires = $xml->{request_signature_expires};

  # I want to follow redirects now.
  $browser->allow_redirects;

  my $url = "$base/play/clip:$id/$request_signature/$request_signature_expires/?q=sd&type=embed";

  return $url, $filename;
}

sub site_break {
  my($self, $browser) = @_;

  if($browser->uri->host eq "embed.break.com") {
    # Embedded video
    if(!$browser->success && $browser->response->header('Location') !~ /sVidLoc/) {
      $browser->get($browser->response->header('Location'));
    }

    if($browser->response->header("Location") =~ /sVidLoc=([^&]+)/) {
      my $url = uri_unescape($1);
      my $filename = title_to_filename((split /\//, $url)[-1]);

      return $url, $filename;
    }
  }

  my $path = ($browser->content =~ /sGlobalContentFilePath='([^']+)'/)[0];
  my $filename = ($browser->content =~ /sGlobalFileName='([^']+)'/)[0];

  die "Unable to extract path and filename" unless $path and $filename;

  my $video_path = ($browser->content =~ /videoPath',\s*'([^']+)/)[0];

  # I want to follow redirects now.
  $browser->allow_redirects;

  return $video_path . $path . "/" . $filename . ".flv",
    title_to_filename($filename);
}

sub generic {
  my ($self, $browser) = @_;

  # First strategy - identify all the Flash video files, and download the
  # biggest one. Yes, this is hacky.
  if (!$browser->success) {
    $browser->get($browser->response->header('Location'));
    die "Couldn't download URL: " . $browser->response->status_line
      unless $browser->success;
  }

  my ($possible_filename, $actual_url, $title, $got_url);
  if ($browser->content =~ /<title>(.*?)<\/title>/i) {
    $title = $1;
    $title =~ s/^(?:\w+\.com)[[:punct:] ]+//g;
    $title = title_to_filename($title); 
  }

  my @flv_urls = map {
    (m|http://.+?(http://.+?\.flv)|) ? $1 : $_
  } ($browser->content =~ m'(http://.+?\.(?:flv|mp4))'g);
  if (@flv_urls) {
    memoize("LWP::Simple::head");
    @flv_urls = sort { (head($a))[1] <=> (head($b))[1] } @flv_urls;
    $possible_filename = (split /\//, $flv_urls[-1])[-1];
    $actual_url = $flv_urls[-1];

    $browser->head($actual_url);
    my $response = $browser->response;
    $got_url = 1 if $response->code == 200;
    my $redirects = 0;
    while ( ($response->code =~ /^30\d/) and ($response->header('Location'))
             and ($redirects < MAX_REDIRECTS) ) {
      my $url = $response->header('Location');
      $response = $browser->head($url);
      if ($response->code == 200) {
        $actual_url = $url;
        $got_url = 1;
        last;
      }
      $redirects++;
    }
  }

  if(!$got_url) {
    RE: for my $regex(
        qr{(?si)<embed.*flashvars=["']?([^"'>]+)},
        qr{(?si)<embed.*src=["']?([^"'>]+)},
        qr{(?si)<object[^>]*>.*?<param [^>]*value=["']?([^"'>]+)},
        # Attempt to handle scripts using flashvars / swfobject
        qr{(?si)<script[^>]*>(.*?)</script>}) {
      for my $param($browser->content =~ /$regex/g) {
        ($actual_url, $possible_filename) = find_file_param($browser, $param);
        if($actual_url) {
          $got_url = 1;
          last RE;
        }
      }
    }
  }

  my @filenames;
  push @filenames, $possible_filename if $possible_filename;
  push @filenames, $title if $title && $title !~ /\Q$possible_filename\E/i;
  push @filenames, get_video_filename() if !@filenames;
  
  return ($actual_url, @filenames) if $got_url;

  # XXX: link to bug tracker here / suggest update, etc...
  die "Couldn't extract Flash movie URL, maybe this site needs specific support adding?";
}

# Utility functions

sub title_to_filename {
  my($title, $type) = @_;
  $type ||= "flv";

  my $has_extension = $title =~ /\.[a-z0-9]{3,4}$/;

  $title = decode_entities($title);
  $title =~ s/\s+/_/g;
  $title =~ s/[^\w\-,()]/_/g;
  $title =~ s/^_+|_+$//g;   # underscores at the start and end look bad

  $title .= ".$type" unless $has_extension;
  return $title;
}

sub get_video_filename {
  my($type) = @_;
  $type ||= "flv";
  return "video" . get_timestamp_in_iso8601_format() . "." . $type; 
}

sub get_timestamp_in_iso8601_format { 
  use Time::localtime; 
  my $time = localtime; 
  return sprintf("%04d%02d%02d%02d%02d%02d", 
                 $time->year + 1900, $time->mon + 1, 
                 $time->mday, $time->hour, $time->min, $time->sec); 
}

sub get_browser {
  my $browser = FlashVideo::Mechanize->new(autocheck => 0);
  $browser->agent_alias("Windows Mozilla");

  return $browser;
}

sub find_file_param {
  my($browser, $param) = @_;

  if($param =~ /(?:video|movie|file)['"]?\s*[=:]\s*['"]?([^&'"]+)/
      || $param =~ /['"=](.*?\.(?:flv|mp4))/) {
    my $file = $1;

    my $actual_url = guess_file($browser, $file);
    if($actual_url) {
      my $possible_filename = (split /\//, $actual_url)[-1];

      return $actual_url, $possible_filename;
    }
  }
  
  return;
}

sub guess_file {
  my($browser, $file) = @_;

  my $uri = URI->new_abs($file, $browser->uri);

  if($uri) {
    $browser->head($uri);
    my $response = $browser->response;

    if($response->code == 200) {
      my $content_type = $response->header("Content-type");

      if($content_type =~ m!^(text|application/xml)!) {
        $browser->get($uri);
        return $1 if $browser->content =~ m!(http[-:/a-zA-Z0-9%_.?=&]+\.(flv|mp4))!;
      } else {
        return $uri->as_string;
      }
    }
  }

  return;
}


1;

