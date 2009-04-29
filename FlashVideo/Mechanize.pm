# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Mechanize;
use WWW::Mechanize;
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

1;
