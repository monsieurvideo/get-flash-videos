# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Mechanize;
use WWW::Mechanize;
use LWP::Protocol::https;
use FlashVideo::Downloader;
use Encode ();

use strict;
use base "WWW::Mechanize";

sub new {
  my $class = shift;
  my $browser = $class->SUPER::new(autocheck => 0, parse_head => 0);
  $browser->agent_alias("Windows Mozilla");

  my $proxy = $App::get_flash_videos::opt{proxy};

  if ($proxy) {
    if ($proxy =~ m%^(\w+://)?([.\w-]+)(:\d+)?$%) {
      # Proxy is in format:
      #   localhost:1337
      #   localhost
      #   [socks|http|...]://localhost:8080
      # Add a scheme so LWP can use it.
      # Other formats are passed to LWP directly.
      my ($scheme, $host, $port) = ($1, $2, $3);

      $scheme ||= "socks://";
      my $sndport = ":8080";
      $sndport = ":1080" if ($scheme =~ /socks/);
      $port ||= $sndport; # socks by default

      $proxy = $scheme.$host.$port;

    }
    print STDERR "Using proxy server $proxy\n"
      if $App::get_flash_videos::opt{debug};

    $browser->proxy([qw[http https]] => $proxy);
  }

  if($browser->get_socks_proxy) {
    if(!eval { require LWP::Protocol::socks }) {
      die "LWP::Protocol::socks is required for SOCKS support, please install it\n";
    }
  }

  return $browser;
}

sub redirect_ok {
  my($self) = @_;

  return $self->{redirects_ok};
}

sub allow_redirects {
  my($self) = @_;
  $self->{redirects_ok} = 1;
}
sub prohibit_redirects {
  my($self) = @_;
  $self->{redirects_ok} = 0;
}

sub get {
  my($self, @rest) = @_;

  print STDERR "-> GET $rest[0]\n" if $App::get_flash_videos::opt{debug};

  my $r = $self->SUPER::get(@rest);

  if($App::get_flash_videos::opt{debug}) {
    my $text = join " ", $self->response->code,
      $self->response->header("Content-type"), "(" . length($self->content) . ")";
    $text .= ": " . DBI::data_string_desc($self->content) if eval { require DBI };

    print STDERR "<- $text\n";
  }

  return $r;
}

sub update_html {
  my($self, $html) = @_;

  my $charset = _parse_charset($self->response->header("Content-type"));

  # If we have no character set in the header (therefore it is worth looking
  # for a http-equiv in the body) or the content hasn't been decoded (older
  # versions of Mech).
  if($LWP::UserAgent::VERSION < 5.827
    && (!$charset || !Encode::is_utf8($html))) {

    # HTTP::Message helpfully decodes to iso-8859-1 by default. Therefore we
    # do the inverse. This is fucking frail and will probably break.
    $html = Encode::encode("iso-8859-1", $html) if Encode::is_utf8($html);

    # Check this doesn't look like a video..
    if(!FlashVideo::Downloader->check_magic($html)) {
      my $p = HTML::TokeParser->new(\$html);
      while(my $token = $p->get_tag("meta")) {
        my($tag, $attr) = @$token;
        if($tag eq 'meta' && $attr->{"http-equiv"} =~ /Content-type/i) {
          $charset ||= _parse_charset($attr->{content});
        }
      }

      if($charset) {
        eval { $html = Encode::decode($charset, $html) };
        FlashVideo::Utils::error("Failed decoding as $charset: $@") if $@;
      }
    }
  }

  return $self->SUPER::update_html($html);
}

sub _parse_charset {
  my($field) = @_;
  return(($field =~ /;\s*charset=([-_.:a-z0-9]+)/i)[0]);
}

sub get_socks_proxy {
  my $self = shift;
  my $proxy = $self->proxy("http");

  if(defined $proxy && $proxy =~ m!^socks://(.*?):(\d+)!) {
    return "$1:$2";
  }

  return "";
}

1;
