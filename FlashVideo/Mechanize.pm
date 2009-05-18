# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Mechanize;
use WWW::Mechanize;
use Encode;

use strict;
use base "WWW::Mechanize";

sub redirect_ok {
  my($self) = @_;

  return $self->{redirects_ok};
}

sub allow_redirects {
  my($self) = @_;
  $self->{redirects_ok} = 1;
}

sub get {
  my($self, @rest) = @_;

  print STDERR "-> GET $rest[0]\n" if $::opt{debug};

  my $r = $self->SUPER::get(@rest);

  if($::opt{debug}) {
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
  if(!$charset || !Encode::is_utf8($html)) {

    # HTTP::Message helpfully decodes to iso-8859-1 by default. Therefore we
    # do the inverse. This is fucking frail and will probably break.
    $html = Encode::encode("iso-8859-1", $html) if Encode::is_utf8($html);

    my $p = HTML::TokeParser->new(\$html);
    while(my $token = $p->get_tag("meta")) {
      my($tag, $attr) = @$token;
      if($tag eq 'meta' && $attr->{"http-equiv"} =~ /Content-type/i) {
        $charset ||= _parse_charset($attr->{content});
      }
    }

    if($charset) {
      eval { $html = decode($charset, $html) };
      FlashVideo::Utils::error("Failed decoding as $charset: $@") if $@;
    }
  }

  return $self->SUPER::update_html($html);
}

sub _parse_charset {
  my($field) = @_;
  return(($field =~ /;\s*charset=([^ ]+)/i)[0]);
}

1;
