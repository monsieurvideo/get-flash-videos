# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::VideoPreferences::Account;

use strict;

sub new {
  my($class, $site, $prompt) = @_;

  require Net::Netrc; # Core since 5.8

  my $record = Net::Netrc->lookup($site);
  my($user, $pass) = $record ? $record->lpa : ();

  # Allow only setting user in .netrc if wanted

  if(!$user) {
    print $prompt;

    print "Username: ";
    chomp($user = <STDIN>);
  }

  if(!$pass) {
    print "Ok, need your password";
    if(eval { require Term::ReadKey }) {
      print ": ";
      Term::ReadKey::ReadMode(2);
      chomp($pass = <STDIN>);
      Term::ReadKey::ReadMode(0);
      print "\n";
    } else {
      print " (will be displayed): ";
      chomp($pass = <STDIN>);
    }
  }
  
  return bless {
    username => $user,
    password => $pass,
  }, $class;
}

sub username {
  my($self) = @_;
  return $self->{username};
}

sub password {
  my($self) = @_;
  return $self->{password};
}

1;
