package FlashVideo::JSON;
# Very simple JSON parser, loosely based on
# http://code.google.com/p/json-sans-eval
# Public domain.

use strict;
use base 'Exporter';
our @EXPORT = qw(from_json);

my $number = qr{(?:-?\b(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?\b)};
my $oneChar = qr{(?:[^\0-\x08\x0a-\x1f\"\\]|\\(?:["/\\bfnrt]|u[0-9A-Fa-f]{4}))};
my $string = qr{(?:"$oneChar*")};
my $jsonToken = qr{(?:false|true|null|[\{\}\[\]]|$number|$string)};
my $escapeSequence = qr{\\(?:([^u])|u(.{4}))};

my %escapes = (
  '\\' => '\\',
  '"' => '"',
  '/' => '/',
  'b' => "\b",
  'f' => "\f",
  'n' => "\xA",
  'r' => "\xD",
  't' => "\t"
);

sub from_json {
  my($in) = @_;

  my @tokens = $in =~ /$jsonToken/go;
  my $result = $tokens[0] eq '{' ? {} : [];
  # Handle something other than array/object at toplevel
  shift @tokens if $tokens[0] =~ /^[\[\{]/;

  my $key; # key to use for next value
  my @stack = $result;
  for my $t(@tokens) {
    my $ft = substr $t, 0, 1;
    my $cont = $stack[0];

    if($ft eq '"') {
      my $s = substr $t, 1, length($t) - 2;
      $s =~ s/$escapeSequence/$1 ? $escapes{$1} : chr hex $2/geo;
      if(!defined $key) {
        if(ref $cont eq 'ARRAY') {
          $cont->[@$cont] = $s;
        } else {
          $key = $s;
          next; # need to save $key
        }
      } else {
        $cont->{$key} = $s;
      }
    } elsif($ft eq '[' || $ft eq '{') {
      unshift @stack,
        (ref $cont eq 'ARRAY' ? $cont->[@$cont] : $cont->{$key}) = $ft eq '[' ? [] : {};
    } elsif($ft eq ']' || $ft eq '}') {
      shift @stack;
    } else {
      (ref $cont eq 'ARRAY' ? $cont->[@$cont] : $cont->{$key}) =
          $ft eq 'f' ? 0 # false
        : $ft eq 'n' ? undef # null
        : $ft eq 't' ? 1 # true
        : $t; # sign or digit
    }
    undef $key;
  }

  return $result;
}

1;
