#!perl
use strict;
use lib qw(..);
use utf8; # Test results are in UTF-8.
use Test::More;
use FlashVideo::Utils;
use Encode;

my @tests = (
  [ <<EOF, "text/html", "foo bar"
<Title>foo
bar</title>
EOF
  ],
  [ <<EOF, "text/html; charset=iso-8859-1", "café"
<title
>caf\x{e9}</title>
EOF
  ],
  [ <<EOF, "text/html; charset=windows-1251", "Российская Федерация"
<title>\xD0\xEE\xF1\xF1\xE8\xE9\xF1\xEA\xE0\xFF\x20\xD4\xE5\xE4\xE5\xF0\xE0\xF6\xE8\xFF</title>
EOF
  ],
  [ <<EOF, "text/html", "Российская Федерация"
<META http-equiv=content-type content="text/html; CHARSET=windows-1251" />
<title>\xD0\xEE\xF1\xF1\xE8\xE9\xF1\xEA\xE0\xFF\x20\xD4\xE5\xE4\xE5\xF0\xE0\xF6\xE8\xFF</title>
EOF
  ],
  [ <<EOF, "text/html", "NTTドコモのオフィシャルウェブサイトです。"
<title>\x4E\x54\x54\x83\x68\x83\x52\x83\x82\x82\xCC\x83\x49\x83\x74\x83\x42\x83\x56\x83\x83\x83\x8B\x83\x45\x83\x46\x83\x75\x83\x54\x83\x43\x83\x67\x82\xC5\x82\xB7\x81\x42</title>
<meta http-equiv="content-type" content="text/html; charset=shift_jis">
EOF
  ]
);

# These aren't actually in UTF-8, hence the evilness.
Encode::_utf8_off($_->[0]) for @tests;

{ # Mock version of WWW::Mechanize
  package MockMech;
  use base "FlashVideo::Mechanize";

  sub _make_request {
    my($self, $req) = @_;

    my $num = $req->uri->host;

    my $res = HTTP::Response->new(200, "OK",
      [ "Content-type" => $tests[$num]->[1] ],
      $tests[$num]->[0]);

    $res->request($req);

    return $res;
  }
}

# Start tests..

plan tests => scalar @tests;

my $mech = MockMech->new;
for my $i(0 .. $#tests) {
  $mech->get("http://$i");
  is(extract_title($mech), $tests[$i]->[2]);
}
