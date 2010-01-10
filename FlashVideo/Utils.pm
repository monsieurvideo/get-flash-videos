# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Utils;

use strict;
use base 'Exporter';
use HTML::Entities;
use HTML::TokeParser;
use Encode;

use constant FP_KEY => "Genuine Adobe Flash Player 001";
use constant EXTENSIONS => qr/\.(?:flv|mp4|mov|wmv|avi)/i;
use constant MAX_REDIRECTS => 5;

our @EXPORT = qw(debug info error
  extract_title extract_info title_to_filename get_video_filename url_exists
  swfhash swfhash_data EXTENSIONS get_user_config_dir get_win_codepage
  is_program_on_path get_terminal_width);

my $HAS_READKEY = eval { require Term::ReadKey };

sub debug(@) {
  # Remove some sensitive data
  my $string = "@_\n";
  $string =~ s/\Q$ENV{HOME}\E/~/g;
  print STDERR $string if $::opt{debug};
}

sub info(@) {
  print STDERR "@_\n" unless $::opt{quiet};
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
  $type ||= "flv";

  # Extract the extension if we're passed a URL.
  $type = substr $1, 1 if $title =~ s/(@{[EXTENSIONS]})$//;
  $type = substr $1, 1 if $type =~ s/(@{[EXTENSIONS]})$//;

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

  Win32::API->Import("kernel32", "int GetACP()");
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
  if($HAS_READKEY && (my($width) = Term::ReadKey::GetTerminalSize())) {
    return $width - 1 if $^O =~ /MSWin/i; # seems to be off by 1 on Windows
    return $width;
  } elsif($ENV{COLUMNS}) {
    return $ENV{COLUMNS};
  } else {
    return 80;
  }
}

1;
