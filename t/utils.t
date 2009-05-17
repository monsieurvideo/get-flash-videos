#!perl
use strict;
use lib qw(..);
use utf8; # This file is in UTF-8.
use Test::More tests => 4;
use FlashVideo::Utils;

# Mock version of WWW::Mechanize
{ package MockMech;

  sub new {
    my(undef, $content, $ct) = @_;
    return bless { content => $content, ct => $ct };
  }

  sub content {
    my($self) = @_;
    return $self->{content};
  }

  sub ct {
    my($self) = @_;
    return $self->{ct};
  }
}

my $m = MockMech->new(<<EOF, "text/html");
<Title>foo
bar</title>
EOF
is(extract_title($m), "foo bar");

$m = MockMech->new(<<EOF, "text/html; charset=iso-8859-1");
<title
>caf\x{e9}</title>
EOF
is(extract_title($m), "café");

$m = MockMech->new(<<EOF, "text/html");
<META http-equiv=content-type content="text/html; CHARSET=windows-1251" />
<title>\xD0\xEE\xF1\xF1\xE8\xE9\xF1\xEA\xE0\xFF\x20\xD4\xE5\xE4\xE5\xF0\xE0\xF6\xE8\xFF</title>
EOF
is(extract_title($m), "Российская Федерация");

$m = MockMech->new(<<EOF, "text/html");
<title>\x4E\x54\x54\x83\x68\x83\x52\x83\x82\x82\xCC\x83\x49\x83\x74\x83\x42\x83\x56\x83\x83\x83\x8B\x83\x45\x83\x46\x83\x75\x83\x54\x83\x43\x83\x67\x82\xC5\x82\xB7\x81\x42</title>
<meta http-equiv="content-type" content="text/html; charset=shift_jis">
EOF
is(extract_title($m), "NTTドコモのオフィシャルウェブサイトです。");

