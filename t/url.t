#!perl
use strict;
use lib qw(..);
use constant DEBUG => $ENV{DEBUG};
use Test::More;
use File::Path;
use FlashVideo::Downloader;

BEGIN { $ENV{PERL5LIB} = "../.." }

# We don't want to do this unless they really meant it, as it downloads a lot.
unless($ENV{SITE} || $ENV{SURE}) {
  plan skip_all => "RTFS";
  exit;
}

my @urls = assemble_urls();
plan tests => 5 * scalar @urls;

my $i = 0;
for my $url_info(@urls) {
  my($url, $note) = @$url_info;

  my $dir = "test-" . ++$i;
  mkpath $dir;
  chdir $dir or next;

  diag "Testing $note";

  my $pid = open my $out_fh, "-|", "../../get_flash_videos --yes '$url' 2>&1";

  while(<$out_fh>) {
    DEBUG && diag $_;
  }

  waitpid $pid, 0;
  ok $? == 0, $note;

  my @files = <*.{mp4,flv}>;
  ok @files == 1, "One file downloaded";

  ok($files[0] !~ /^video\d{14}\./, "Has good filename");

  ok(FlashVideo::Downloader->check_file($files[0]), "File is a media file");

  ok -s $files[0] > (1024*200), "File looks big enough";

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
