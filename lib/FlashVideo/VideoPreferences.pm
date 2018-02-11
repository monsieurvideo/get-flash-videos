# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::VideoPreferences;

use strict;
use FlashVideo::VideoPreferences::Quality;
use FlashVideo::VideoPreferences::Account;

sub new {
  my($class, %opt) = @_;

  return bless {
    raw => $opt{raw} || 1,
    quality => $opt{quality} || "high",
    subtitles => $opt{subtitles} || 0,
    type => $opt{type} || "",
  }, $class;
}

sub quality {
  my($self) = @_;

  return FlashVideo::VideoPreferences::Quality->new($self->{quality});
}

sub subtitles {
  my($self) = @_;

  return $self->{subtitles};
}

sub account {
  my($self, $site, $prompt) = @_;

  return FlashVideo::VideoPreferences::Account->new($site, $prompt);
}

1;
