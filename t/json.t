#!perl
use strict;
use lib qw(..);
use Test::More tests => 9;

BEGIN {
  use_ok "FlashVideo::JSON";
}

is_deeply(from_json('{"foo": "bar"}'), { foo => "bar" });
is_deeply(from_json('{"foo": "bar", "baz": { "foo" : 2, "bar": 
    [1,2,
    3] }  }'),
  { foo => "bar", baz => { foo => 2, bar => [1,2,3] } });

is_deeply(from_json('[1,2,3,4]'), [1,2,3,4]);

is_deeply(from_json('"hello"'), ["hello"]);
is_deeply(from_json('"\u3053\u3093\u306b\u3061\u308f"'), ["\x{3053}\x{3093}\x{306b}\x{3061}\x{308f}"]);
is_deeply(from_json('false'), [0]);
is_deeply(from_json('true'), [1]);
is_deeply(from_json('null'), [undef]);

