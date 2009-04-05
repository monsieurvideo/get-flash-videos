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

1;
