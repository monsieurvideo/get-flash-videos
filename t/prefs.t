#!perl
use Test::More tests => 24;

BEGIN {
  use_ok("FlashVideo::VideoPreferences");
}

my $prefs = FlashVideo::VideoPreferences->new;
isa_ok $prefs, FlashVideo::VideoPreferences;

# ---- Quality ----
my $q = $prefs->quality;
isa_ok $q, FlashVideo::VideoPreferences::Quality;

# Default is high quality
is $q->name, "high";

# Check formats are understood

# Standard names
is_deeply $q->format_to_resolution("720p"), [1280, 720, "high"];
is_deeply $q->format_to_resolution("480p"), [640, 480, "medium"];

# Unknown name, but a number
is_deeply $q->format_to_resolution("100"), [100, 100, "low"];

# Totally unknown
eval { $q->format_to_resolution("random") };
like $@, qr/Unknown format/;

# Converting a resolution to a quality
is $q->resolution_to_quality([2000, 2000]), "high";
is $q->resolution_to_quality([1000, 563]), "high";
is $q->resolution_to_quality([500, 500]), "medium";
is $q->resolution_to_quality([400, 400]), "low";
is $q->resolution_to_quality([200, 200]), "low";

# Converting a quality to a resolution
is_deeply $q->quality_to_resolution("high"), [1920, 1080, "high"];
is_deeply $q->quality_to_resolution("medium"), [720, 576, "medium"];
is_deeply $q->quality_to_resolution("low"), [427, 240, "low"];
is_deeply $q->quality_to_resolution("720p"), [1280, 720, "high"];
is_deeply $q->quality_to_resolution("1024x768"), [1024, 768, "high"];
is_deeply $q->quality_to_resolution("640x480"), [640, 480, "medium"];
is_deeply $q->quality_to_resolution("100x100"), [100, 100, "low"];

# Choosing quality

# High, should choose highest..
is_deeply $q->choose(
  { resolution => [1024, 768], url => "ok" },
  { resolution => [640, 480], url => "nok" }) => { resolution => [1024, 768], url => "ok" };

# Medium
$q = FlashVideo::VideoPreferences::Quality->new("medium");
is_deeply $q->choose(
  { resolution => [1024, 768], url => "nok" },
  { resolution => [640, 480], url => "ok" }) => { resolution => [640, 480], url => "ok" };

# Low - not available so chooses lowest possible.
$q = FlashVideo::VideoPreferences::Quality->new("low");
is_deeply $q->choose(
  { resolution => [1024, 768], url => "nok" },
  { resolution => [640, 480], url => "ok" }) => { resolution => [640, 480], url => "ok" };

# Multiple low available, chooses highest quality low.
is_deeply $q->choose(
  { resolution => [320, 240], url => "nok" },
  { resolution => [3200, 2400], url => "nok" },
  { resolution => [800, 240], url => "nok" },
  { resolution => [427, 200], url => "ok" }) => { resolution => [427, 200], url => "ok" };

