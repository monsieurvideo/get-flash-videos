#!perl
use strict;
use lib qw(..);
use constant DEBUG => $ENV{DEBUG};
use IPC::Open3;
use Test::More;
use File::Path;
use FlashVideo::Downloader;

my $script = $ENV{SCRIPT} ? "$ENV{SCRIPT}" : "../../blib/script/get_flash_videos";

chdir "t";

if($ENV{AUTOMATED_TESTING} && $ENV{PERL5_CPAN_IS_RUNNING}) {
  $ENV{SITE} = "\\[cpan\\]"; # a subset of tests specially for CPAN testers
} elsif(!$ENV{SITE}) {
  # We don't want to do this unless they really meant it, as it downloads a lot.
  plan skip_all => "Not going online, set SITE to run these tests";
  exit;
}

require FlashVideo::Mechanize;
my $mech = FlashVideo::Mechanize->new;
$mech->get("http://www.google.com");
plan skip_all => "We don't appear to have an internet connection"
  if $mech->response->is_error;

my @urls = assemble_urls();
plan tests => 5 * scalar @urls;

my $i = 0;
for my $url_info(@urls) {
  my($url, $note) = @$url_info;
  $note =~ s/\[.*?\]//g; # metadata (e.g. if cpan testers should run this?)

  my $dir = "test-" . ++$i;
  mkpath $dir;
  chdir $dir or next;

  diag "Testing $note";

  # Allow backticks for URLs that change
  $url =~ s/\`(.*)\`/`$1`/e;

  my $pid = open3(my $in_fh, my $out_fh, 0,
    $^X, "$script", "--yes", '--filename', 'cpan_testing_video', $url);

  while(<$out_fh>) {
    DEBUG && diag $_;
  }

  waitpid $pid, 0;
  ok $? == 0, $note;

  #DEBUG && diag "Files in directory: ", <*>;

  #my @files = <*.{mp4,flv,mov}>;
  my $file = "cpan_testing_video";
  #ok @files == 1, "One file downloaded";

  #ok($files[0] !~ /^video\d{14}\./, "Has good filename");

  ok(FlashVideo::Downloader->check_file($file), "File is a media file");

  ok -s $file > (1024*200), "File looks big enough";

  chdir "..";
  rmtree $dir;
}

sub assemble_urls {
  my @urls;

  open my $url_fh, "<", "urls" or die $!;
  my $note;
  while(<$url_fh>) {
    chomp;

    if(/^#\s*(.*)/) {
      $note = $1;
    } elsif(/^\S/) {
      next if $ENV{SITE} && $note !~ /$ENV{SITE}/i;
      push @urls, [ $_, $note ];
    }
  }

  return @urls;
}
