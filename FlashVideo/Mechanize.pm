# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Mechanize;
use WWW::Mechanize;
use Encode;

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

  print STDERR "GET @rest " if $::opt{debug};

  my $r = $self->SUPER::get(@rest);

  print STDERR join " ", $self->response->code,
    $self->response->header("Content-type"),
    "(" . length($self->content) . ")\n" if $::opt{debug};

  return $r;
}

sub update_html {
  my($self, $html) = @_;

  if(!Encode::is_utf8($html)) {
    # The header should have been looked at already, but maybe this is an old
    # version.
    my $charset = _parse_charset($browser->ct);

    my $p = HTML::TokeParser->new(\$html);
    while(my $token = $p->get_tag("meta")) {
      my($tag, $attr) = @$token;
      if($tag eq 'meta' && $attr->{"http-equiv"} =~ /Content-type/i) {
        $charset ||= _parse_charset($attr->{content});
      }
    }

    if($charset) {
      eval { $html = decode($charset, $html) };
      FlashVideo::Utils::debug("Failed decoding as $charset: $@") if $@;
    }
  }

  return $self->SUPER::update_html($html);
}

sub _parse_charset {
  my($field) = @_;
  return(($field =~ /;\s*charset=([^ ]+)/i)[0]);
}

1;
