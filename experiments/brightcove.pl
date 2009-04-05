#!/usr/bin/perl
use strict;
use File::Slurp;
use Data::AMF::Packet;
use LWP::UserAgent;
use Data::Dumper;
use Getopt::Long;

my $ua = LWP::UserAgent->new;

my $videoId  = undef;
my $playerId = undef;

GetOptions(
  "video=s" => \$videoId,
  "player=s" => \$playerId
);

if(@ARGV && $ARGV[0] =~ /^http/i) {
  # Try and scrape the ids from the page
  my $r = $ua->get($ARGV[0]);

  if(!defined $videoId) {
    $videoId = ($r->content =~ /videoId["'\] ]*=["' ]*(\d+)/)[0];
  }

  if(!defined $playerId) {
    $playerId = ($r->content =~ /playerId["'\] ]*=["' ]*(\d+)/)[0];
  }

  if(!defined $videoId && $ARGV[0] =~ /bctid=(\d+)/) {
    $videoId = $1;
  }

  if(!$playerId) {
    die "Unable to extract IDs from page?\n";
  }
}

if(!defined $videoId && !defined $playerId) {
  die "Usage: $0 [--video ID] [--player ID] [url]\n";
}

# XXX: create this from scratch
my $data = read_file "req.amf";
my $packet = Data::AMF::Packet->deserialize($data);

if(defined $playerId) {
  $packet->messages->[0]->{value}->[0] = "$playerId";
}

if(defined $videoId) {
  $packet->messages->[0]->{value}->[1]->{videoId} = "$videoId";
}

$data = $packet->serialize;

my $res = $ua->post("http://c.brightcove.com/services/amfgateway",
  Content_Type => "application/x-amf",
  Content => $data);

my $packet = Data::AMF::Packet->deserialize($res->content);
print Dumper $packet;

my @found;
for(@{$packet->messages->[0]->{value}}) {
  if($_->{data}->{videoDTO}) {
    push @found, $_->{data}->{videoDTO};
  }
  if($_->{data}->{videoDTOs}) {
    push @found, @{$_->{data}->{videoDTOs}};
  }
}

print Dumper @found;

for my $d(@found) {
  my $host = ($d->{FLVFullLengthURL} =~ m!rtmp://(.*?)/!)[0];
  my $file = ($d->{FLVFullLengthURL} =~ m!&(media.*?)&!)[0];
  my $app = ($d->{FLVFullLengthURL} =~ m!//.*?/(.*?)/&!)[0];
  my $filename = ($d->{FLVFullLengthURL} =~ m!&.*?/([^/&]+)&!)[0];

  my $args = {
    swfUrl => "http://admin.brightcove.com/viewer/federated/f_012.swf?bn=590&pubId=$d->{publisherId}",
    app => "$app?videoId=$d->{videoId}&lineUpId=$d->{lineUpId}&pubId=$d->{publisherId}&playerId=$d->{playerId}",
    tcUrl => $d->{FLVFullLengthURL},
    auth => ($d->{FLVFullLengthURL} =~ /&(media.*)/)[0],
    rtmp => "rtmp://$host/slist=$file",
    flv => "$filename.flv"
  };

  if($ENV{DEBUG}) {
    print "rtmpdump ", join " ", map { ("--$_" => "'" . $args->{$_} . "'") } keys %$args;
    print "\n";
  }

  system("rtmpdump", map { ("--$_" => $args->{$_}) } keys %$args);
}

