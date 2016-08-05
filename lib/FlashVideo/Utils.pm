# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Utils;

use strict;
no warnings 'uninitialized';
use base 'Exporter';
use HTML::Entities;
use HTML::TokeParser;
use Encode;

use constant FP_KEY => "Genuine Adobe Flash Player 001";
use constant EXTENSIONS => qr/\.(?:flv|mp4|mov|wmv|avi|m4v)/i;
use constant MAX_REDIRECTS => 5;

our @EXPORT = qw(debug info error
  extract_title extract_info title_to_filename get_video_filename url_exists
  swfhash swfhash_data EXTENSIONS get_user_config_dir get_win_codepage
  is_program_on_path get_terminal_width json_unescape
  convert_sami_subtitles_to_srt convert_dc_subtitles_to_srt from_xml
  convert_ttml_subtitles_to_srt read_hls_playlist);

sub debug(@) {
  # Remove some sensitive data
  my $string = "@_\n";
  $string =~ s/\Q$ENV{HOME}\E/~/g;
  print STDERR $string if $App::get_flash_videos::opt{debug};
}

sub info(@) {
  print STDERR "@_\n" unless $App::get_flash_videos::opt{quiet};
}

sub error(@) {
  print STDERR "@_\n";
}

sub extract_title {
  my($browser) = @_;
  return extract_info($browser)->{title};
}

sub extract_info {
  my($browser) = @_;
  my($title, $meta_title);

  my $p = HTML::TokeParser->new(\$browser->content);
  while(my $token = $p->get_tag("title", "meta")) {
    my($tag, $attr) = @$token;

    if($tag eq 'meta' && $attr->{name} =~ /title/i) {
      $meta_title = $attr->{content};
    } elsif($tag eq 'title') {
      $title = $p->get_trimmed_text;
    }
  }

  return {
    title => $title, 
    meta_title => $meta_title,
  };
}

sub swfhash {
  my($browser, $url) = @_;

  $browser->get($url);

  return swfhash_data($browser->content, $url);
}

sub swfhash_data {
  my ($data, $url) = @_;

  die "Must have Compress::Zlib and Digest::SHA for this RTMP download\n"
      unless eval {
        require Compress::Zlib;
        require Digest::SHA;
      };

  $data = "F" . substr($data, 1, 7)
              . Compress::Zlib::uncompress(substr $data, 8);

  return
    swfsize => length $data,
    swfhash => Digest::SHA::hmac_sha256_hex($data, FP_KEY),
    swfUrl  => $url;
}

sub url_exists {
  my($browser, $url) = @_;

  $browser->head($url);
  my $response = $browser->response;
  debug "Exists on $url: " . $response->code;
  return $url if $response->code == 200;

  my $redirects = 0;
  while ( ($response->code =~ /^30\d/) and ($response->header('Location'))
      and ($redirects < MAX_REDIRECTS) ) {
    $url = URI->new_abs($response->header('Location'), $url);
    $response = $browser->head($url);
    debug "Redirected to $url (" . $response->code . ")";
    if ($response->code == 200) {
      return $url;
    }
    $redirects++;
  }

  return '';
}

sub title_to_filename {
  my($title, $type) = @_;

  # no need to go any further if "--filename" option is passed
  if($App::get_flash_videos::opt{filename} ne '') {
    return $App::get_flash_videos::opt{filename};
  }

  # Extract the extension if we're passed a URL.
  if($title =~ s/(@{[EXTENSIONS]})$//) {
    $type = substr $1, 1;
  } elsif ($type && $type !~ /^\w+$/) {
    $type = substr((URI->new($type)->path =~ /(@{[EXTENSIONS]})$/)[0], 1);
  }

  $type ||= "flv";

  eval { $title = decode_utf8($title) };

  # We want \w below to match non-ASCII characters.
  utf8::upgrade($title);

  # Some sites have double-encoded entities, so handle this
  if ($title =~ /&(?:\w+|#(?:\d+|x[A-F0-9]+));/) {
    # Double-encoded - decode again
    $title = decode_entities($title);
  }

  $title =~ s/\s+/_/g;
  $title =~ s/[^\w\-,()&]/_/g;
  $title =~ s/^_+|_+$//g;   # underscores at the start and end look bad

  $title = encode_utf8($title);

  # If we have nothing then return a filestamped filename.
  return get_video_filename($type) unless $title;

  return "$title.$type";
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

sub get_vlc_exe_from_registry {
  if ($^O !~ /MSWin/i) {
    die "Doesn't make sense to call this except on Windows";
  }

  my $HAS_WIN32_REGISTRY = eval { require Win32::Registry };

  die "Win32::Registry required for JustWorks(tm) playing on Windows"
    unless $HAS_WIN32_REGISTRY;

  require Win32::Registry;

  # This module, along with Win32::TieRegistry, is horrible and primarily
  # works by exporting various symbols into the calling package.
  # Win32::TieRegistry does not offer an easy way of getting the $Registry
  # object if you require the module rather than use-ing it.
  Win32::Registry->import();
  
  # Ignoring the fact that polluting your caller's namespace is bad
  # practice, it's also evil because I now have to disable strict so that
  # Perl won't complain that $HKEY_LOCAL_MACHINE which is exported into my
  # package at runtime doesn't exist.
  my $local_machine;

  {
    no strict 'vars';
    $local_machine = $::HKEY_LOCAL_MACHINE;
  }

  my $key = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall';

  $local_machine->Open($key, my $reg);

  # Believe it or not, this is Perl, not C
  my @applications;
  $reg->GetKeys(\@applications);

  my $vlc_binary;

  foreach my $application (@applications) {
    next unless $application =~ /VLC Media Player/i;

    $reg->Open($application, my $details);

    my %app_properties;
    $details->GetValues(\%app_properties);

    # These values are arrayrefs with value name, type and data. data is
    # what we care about.
    if ($app_properties{DisplayIcon}->[-1] =~ /\.exe$/i) {
      # Assume this is the VLC executable
      $vlc_binary = $app_properties{DisplayIcon}->[-1];
      last;
    }
  }
  
  return $vlc_binary;
}

sub get_win_codepage {
  require Win32::API;

  # Hack for older versions of Win32::API::Type (which Win32::API->import
  # uses to parse prototypes) to avoid "unknown output parameter type"
  # warning. Older versions of this module have an INIT block for reading
  # type information from the DATA filehandle. This doesn't get called when
  # we require the module rather than use-ing it. More recent versions of
  # the module don't bother with an INIT block, and instead just have the
  # initialisation code at package level.
  if (! %Win32::API::Type::Known) {
    %Win32::API::Type::Known = (int => 'i');
  }

  unless (defined &GetACP) {
    Win32::API->Import("kernel32", "int GetACP()");
  }
  return "cp" . GetACP();
}

# Returns a path to the user's configuration data and/or plugins directory.
sub get_user_config_dir {
  # On Windows, use "Application Data" and "get_flash_videos". On other
  # platforms, use the user's home directory (specified by the HOME
  # environment variable) and ".get_flash_videos". Note that on Windows,
  # the directory has no . prefix as historically, Windows and Windows
  # applications tend to make dealing with such directories awkward.

  # Note that older versions of Windows don't set an APPDATA environment
  # variable.

  return $^O =~ /MSWin/i ? ($ENV{APPDATA} || 'c:/windows/application data')
                            . "/get_flash_videos"
                         : "$ENV{HOME}/.get_flash_videos";
}

# Is the specified program on the system PATH?
sub is_program_on_path {
  my($program) = @_;
  my $win = $^O =~ /MSWin/i;

  for my $dir(split($win ? ";" : ":", $ENV{PATH})) {
    return 1 if -f "$dir/$program" . ($win ? ".exe" : "");
  }
  return 0;
}

sub get_terminal_width {
  if(eval { require Term::ReadKey } && (my($width) = Term::ReadKey::GetTerminalSize())) {
    return $width - 1 if $^O =~ /MSWin|cygwin/i; # seems to be off by 1 on Windows
    return $width;
  } elsif($ENV{COLUMNS}) {
    return $ENV{COLUMNS};
  } else {
    return 80;
  }
}

# Maybe should use a proper JSON parser, but want to avoid the dependency for now..
# (There is now one in FlashVideo::JSON, so consider that -- this is just here
# until we have a chance to fix things using it).
sub json_unescape {
  my($s) = @_;

  $s =~ s/\\u([0-9a-f]{1,4})/chr hex $1/ge;
  $s =~ s{(\\[\\/rnt"])}{"\"$1\""}gee;
  return $s;
}

sub convert_ttml_subtitles_to_srt {
  my ($ttml_subtitles, $filename) = @_;

  die "TTML subtitles must be provided\n" unless  $ttml_subtitles;
  die "Output filename must be provided\n" unless $filename;
  if ( -f $filename ) {
    info "Subtitles already saved";
    return;
  }

  my %ccodes = ( 
    'black',   '#000000',
    'blue',    '#0000ff',
    'aqua',    '#00ffff',
    'lime',    '#00ff00',
    'fuchsia', '#ff00ff', 
    'fuscia',  '#ff00ff',
    'red',     '#ff0000',
    'yellow',  '#ffff00',
    'white',   '#ffffff',
    'navy',    '#000080',
    'teal',    '#008080',
    'green',   '#008000',
    'purple',  '#800080',
    'maroon',  '#800000',
    'olive',   '#808000',
    'gray',    '#808080',
    'silver',  '#c0c0c0');

  unlink($filename);
  open( my $fh, "> $filename");
  binmode $fh;

  my $st_count = 1;
  my @lines = grep /<p\s.*begin=/, split /\n/, $ttml_subtitles;
  for ( @lines ) {
    my ( $start_time, $end_time, $st_text );
    # Remove >1 spaces if not preserved
    s|\s{2,}| |g unless (m%space\s=\s"preserve"%);
    ( $start_time, $end_time, $st_text ) = ( $1, $2, $3 ) if m{<p\s+.*begin="(.+?)".+end="(.+?)".*?>(.+?)<\/p>};
    if ($start_time && $end_time && $st_text ) {
      # Format numerical field widths
      $start_time = sprintf( '%02d:%02d:%02d,%02d', split /[:\.,]/, $start_time );
      $end_time = sprintf( '%02d:%02d:%02d,%02d', split /[:\.,]/, $end_time );
      # Add trailing zero if ttxt format only uses hundreths of a second
      $start_time .= '0' if $start_time =~ m{,\d\d$};
      $end_time .= '0' if $end_time =~ m{,\d\d$};
      # Separate individual lines based on <span>s
      my $i = index $st_text, "<span";
      while ($i >= 0) {
        my $j = index $st_text, "</span>", $i;
        if ($j > 0) {
          my $span = substr($st_text, $i, $j-$i+7);
          my $k = index $span, ">";
          my ( $span_ctl, $span_text ) = ($span =~ m|<span ([^>]+)>(.*)</span>|);
          my ($span_color) =  ($span_ctl =~ m|tts:color="(\w+)"|);
          $span = '<font color="'. $ccodes{$span_color} . '">' . $span_text . "</font>\n";
          $st_text = substr($st_text, 0, $i) . "\n" . $span . substr($st_text, $j+7) . "\n"; 
        }
        $i = index $st_text, "<span";
      }
      $st_text =~ s|<span.*?>(.*?)</span>|\n$1\n|g;
      $st_text =~ s|<br.*?>|\n|g;
      if ($st_text =~ m{\n}) {
        chomp($st_text);
        $st_text =~ s|^\n?||;
        $st_text =~ s|\n?$||;
        $st_text =~ s|\n+|\n|g;
      }
      decode_entities($st_text);
      # Write to file
      print $fh "$st_count\n";
      print $fh "$start_time --> $end_time\n";
      print $fh "$st_text\n\n";
      $st_count++;
    }
  }       
  close $fh;

  return;
}

sub convert_dc_subtitles_to_srt {
  my ($dc_subtitles, $srt_filename) = @_;
  die "DC subtitles must be provided" unless $dc_subtitles;
  die "Output SRT filename must be provided" unless $srt_filename;

  my $xml = from_xml($dc_subtitles, ForceArray => 1);

  open my $srt_fh, '>:encoding(UTF-8)', $srt_filename
    or die "Can't open subtitles file $srt_filename: $!";

  for my $text (@{$xml->{Font}[0]->{Subtitle}}) {
    my $subtitle = "";

    for my $line (@{$text->{Text}}) {
      $subtitle = $subtitle . $line->{content} . "\n";
    }

    print $srt_fh
        "$text->{SpotNumber}\n"
      . "$text->{TimeIn} --> $text->{TimeOut}\n"
      . "$subtitle\n";
  }
}

sub convert_sami_subtitles_to_srt {
  my ($sami_subtitles, $filename, $decrypt_callback) = @_;

  die "SAMI subtitles must be provided"      unless $sami_subtitles;
  die "Output SRT filename must be provided" unless $filename;

  # Use regexes to "parse" SAMI since HTML::TokeParser is too awkward. It
  # makes it hard to preserve linebreaks and other formatting in subtitles.
  # It's also quite slow.
  $sami_subtitles =~ s/[\r\n]//g; # flatten

  my @lines = split /<Sync\s/i, $sami_subtitles;
  shift @lines; # Skip headers

  my @subtitles;
  my $count = 0;

  my $last_proper_sub_end_time = '';

  for (@lines) {
    my ($begin, $sub);
    # Remove span elements
    s|<\/?span.*?>| |g;
    
    # replace "&amp;" with "&"
    s|&amp;|&|g;

    # replace "&nbsp;" with " "
    s{&(?:nbsp|#160);}{ }g;

    # Start="2284698"><P Class="ENCC">I won't have to drink it<br />in this crappy warehouse.</P></Sync>
    #($begin, $sub) = ($1, $2) if m{.*Start="(.+?)".+<P.+?>(.+?)<\/p>.*?<\/Sync>}i;

    ($begin, $sub) = ($1, $2) if m{[^>]*Start="(.+?)"[^>]*>(.*?)<\/Sync>}i;

    if (/^\s*Encrypted="true"\s*/i) {
      if ($decrypt_callback and ref($decrypt_callback) eq 'CODE') {
        $sub = $decrypt_callback->($sub);
      }
    }

    $sub =~ s@&amp;@&@g;
    $sub =~ s@(?:</?span[^>]*>|&nbsp;|&#160;)@ @g;

    # Do some tidying up.
    # Note only <P> tags are removed--<i> tags are left in place since VLC
    # and others support this for formatting.
    $sub =~ s{</?P[^>]*?>}{}g;  # remove <P Class="ENCC"> and similar

    # VLC is very sensitive to tag case.
    $sub =~ s{<(/)?([BI])>}{"<$1" . lc($2) . ">"}eg;
    
    decode_entities($sub); # in void context, this works in place

    if ($begin >= 0) {
      # Convert milliseconds into HH:MM:ss,mmm format
      my $seconds = int( $begin / 1000.0 );
      my $ms = $begin - ( $seconds * 1000.0 );
      $begin = sprintf("%02d:%02d:%02d,%03d", (gmtime($seconds))[2,1,0], $ms );

      # Don't strip simple HTML like <i></i> - VLC and other players
      # support basic subtitle styling, see:
      # http://git.videolan.org/?p=vlc.git;a=blob;f=modules/codec/subtitles/subsdec.c

      # Leading/trailing spaces
      $sub =~ s/^\s*(.*?)\s*$/$1/;

      # strip multispaces
      $sub =~ s/\s{2,}/ /g;

      # Replace <br /> (and similar) with \n. VLC handles \n in SubRip files
      # fine. For <br> it is case and slash sensitive.
      $sub =~ s|<br ?\/? ?>|\n|ig;

      $sub =~ s/^\s*|\s*$//mg;

      if ($count and !$subtitles[$count - 1]->{end}) {
        $subtitles[$count - 1]->{end} = $begin;
      }

      # SAMI subtitles are a bit crap. Only a start time is specified for
      # each subtitle. No end time is specified, so the subtitle is displayed
      # until the next subtitle is ready to be shown. This means that if
      # subtitles aren't meant to be shown for part of the video, a dummy
      # subtitle (usually just a space) has to be inserted.
      if (!$sub or $sub =~ /^\s+$/) {
        if ($count) {
          $last_proper_sub_end_time = $subtitles[$count - 1]->{end};
        }

        # Gap in subtitles.
        next; # this is not a meaningful subtitle
      }

      push @subtitles, {
        start => $begin,
        text  => $sub,
      };

      $count++;
    }
  }

  # Ensure the end time for the last subtitle is correct.
  $subtitles[$count - 1]->{end} = $last_proper_sub_end_time;

  # Write subtitles
  open my $subtitle_fh, '>', $filename
    or die "Can't open subtitles file $filename: $!";

  # Set filehandle to UTF-8 to avoid "wide character in print" warnings.
  # Note this does *not* double-encode data as UTF-8 (verify with hexdump).
  # As per the documentation for binmode: ":utf8 just marks the data as
  # UTF-8 without further checking". This will cause mojibake if 
  # ISO-8859-1/Latin1 and UTF-8 and are mixed in the same file though.
  binmode $subtitle_fh, ':utf8';

  $count = 1;

  foreach my $subtitle (@subtitles) {
    print $subtitle_fh "$count\n$subtitle->{start} --> $subtitle->{end}\n" .
                       "$subtitle->{text}\n\n";
    $count++;
  }

  close $subtitle_fh;

  return 1;
}

sub from_xml {
  my($xml, @args) = @_;

  if(!eval { require XML::Simple && XML::Simple::XMLin("<foo/>") }) {
    die "Must have XML::Simple to download " . caller =~ /::([^:])+$/ . " videos\n";
  }

  $xml = eval {
    XML::Simple::XMLin(ref $xml eq 'SCALAR' ? $xml
      : ref $xml ? $xml->content
      : $xml, @args);
  };

  if($@) {
    die "$@ (from ", join("::", caller), ")\n";
  }

  return $xml;
}

sub read_hls_playlist {
  my($browser, $url) = @_;

  $browser->get($url);
  if (!$browser->success) {
    die "Couldn't download m3u file, $url: " . $browser->response->status_line;
  }

  my @lines = split(/\r?\n/, $browser->content);
  my %urltable = ();
  my $i = 0;

  # Fill the url table
  foreach my $line (@lines) {
    if ($line =~ /EXT-X-STREAM-INF/ && $line =~ /BANDWIDTH/) {
      $line =~ /BANDWIDTH=([0-9]*)/;
      $urltable{int($1)} = $lines[$i + 1];
    }
    $i++;
  }

  return %urltable;
}

1;
