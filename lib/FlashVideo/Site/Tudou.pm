package FlashVideo::Site::Tudou;

use strict;
use FlashVideo::Utils;

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my $check_response = sub {
    my ( $message ) = @_;
    return if $browser->success;
    die sprintf $message, $browser->response->code;
  };

=for comment
  SD video
  Watch: http://www.tudou.com/programs/view/wo2YLr4sc44
  Embed: http://www.tudou.com/v/wo2YLr4sc44
  which redirects to:
         http://www.tudou.com/player/outside/player_outside.swf?iid=30599813&default_skin=http://js.tudouui.com/bin/player2/outside/Skin_outside_12.swf&autostart=false&rurl=

  HD video
  Watch: http://hd.tudou.com/program/15950/
  Embed: http://www.tudou.com/v/elcIFKbSjno
  which redirects to:
         http://www.tudou.com/player/outside/player_outside.swf?iid=21170065&default_skin=http://js.tudouui.com/bin/player2/outside/Skin_outside_12.swf&autostart=false&rurl=

=cut

  my $videoID = 0;

  # HD video web page URL, need to extract video ID via javascript variable
  if ( $embed_url =~ m`hd.tudou.com/program/\w+` )
  {
    ( $videoID ) = ( $browser->content =~ /iid: "(\w+)"/ );
  }

  # Otherwise, get the video from the external player URL
  else
  {
    # SD video web page URL, forward to embedded URL to extract location redirect
    if ( $embed_url =~ m`tudou.com/programs/view/(.+)$` )
    {
      $embed_url = sprintf "http://www.tudou.com/v/%s", $1;
      $browser->get( $embed_url );
    }

    # Embedded URL should be a redirect, use that as the current URL
    if ( $browser->response->code eq 302 and $embed_url =~ m`tudou.com/v/(.+)$` )
    {
      $embed_url = $browser->response->header( 'Location' );
    }

    # Video ID is in the URL if we are either at the redirected URL
    # or at the embedded link that sends the redirect
    ( $videoID ) = ( $embed_url =~ m`tudou.com/player/outside/player_outside.swf\?iid=(\d+)` );
  }

  die "Couldn't extract video ID, we are out probably out of date" unless $videoID;
  debug "Using video ID $videoID";

  # Get video info; safe keys seen: YouNeverKnowThat, IAlsoNeverKnow
  # but they're not even verifying either safekey or noCatch
  # (maybe noCatch means no cache?)
  $browser->get(
    sprintf "http://v2.tudou.com/v2/kili?safekey=%s&id=%s&noCatch=%d",
    'YouNeverKnowThat', $videoID, rand( 10000 ) );

  # Fallback URL in case the first one doesn't have our video information
  if ( not $browser->success )
  {
    debug 'Using fallback tudou link for video info';
    $browser->get(
      sprintf "http://v2.tudou.com/v2/cdn?safekey=%s&id=%s&noCatch=%d",
      'YouNeverKnowThat', $videoID, rand( 10000 ) );
  }
  $check_response->( "Couldn't grab video informaton from tudou, server response was %s" );

  # Response is a plain XML document
  return parse_video_info( $browser->content );
}

# Video info is in XML format
sub parse_video_info {
  my ( $raw_xml ) = @_;

=for comment
SD XML structure:
<v
  time="101300" vi="1" ch="5" nls="0"
  title="&#19978;&#28023;&#22320;&#38081;&#37324;&#36339;&#38050;&#31649;&#33310;"
  code="wo2YLr4sc44" enable="1" logo="0" band="1">

  <a></a>
  <b>
    <f w="1" h="0" sha1="46c7a7a5f8953b0c7e07423bfaa7e6cc80c11ee6" size="3110483">
      http://121.12.103.35/flv/030/599/453/30599453.flv?key=7b63b43d51e29716ec4a7c4a218127cb4054c3
    </f>
    <f w="1" h="0" sha1="46c7a7a5f8953b0c7e07423bfaa7e6cc80c11ee6" size="3110483">
      http://125.64.131.8/flv/030/599/453/30599453.flv?key=7b63b43d51e29716ec4a7c4a218127cb4054c3
    </f>
    <f w="1" h="0" sha1="46c7a7a5f8953b0c7e07423bfaa7e6cc80c11ee6" size="3110483">
      http://124.232.132.4/flv/030/599/453/30599453.flv?key=7b63b43d51e29716ec4a7c4a218127cb4054c3
    </f>
    <f w="1" h="0" sha1="46c7a7a5f8953b0c7e07423bfaa7e6cc80c11ee6" size="3110483">
      http://123.134.67.76/flv/030/599/453/30599453.flv?key=7b63b43d51e29716ec4a7c4a218127cb4054c3
    </f>
    <f w="1" h="0" sha1="46c7a7a5f8953b0c7e07423bfaa7e6cc80c11ee6" size="3110483">
      http://125.211.196.8/flv/030/599/453/30599453.flv?key=7b63b43d51e29716ec4a7c4a218127cb4054c3
    </f>
  </b>
</v>

HD XML structure:
<v
  time="2566570" vi="" ch="22" nls="0"
  title="&#25105;&#30340;&#38738;&#26149;&#35841;&#20570;&#20027;(1-3)AA"
  code="elcIFKbSjno" enable="1" logo="0" band="0">

  <a></a>
  <b>
    <f w="1" h="0" sha1="5aa07d5920dbc600e1d7256e2a9f90c9a3e05870" size="155830642">
      http://121.12.103.43/mp4/021/170/065/21170065.f4v?key=1d0399b5a9fa36b8b7f8004a21a241cb4054c3
    </f>
    <f w="1" h="0" sha1="5aa07d5920dbc600e1d7256e2a9f90c9a3e05870" size="155830642">
    http://123.134.67.67/mp4/021/170/065/21170065.f4v?key=1d0399b5a9fa36b8b7f8004a21a241cb4054c3
    </f>
    <f w="1" h="0" sha1="5aa07d5920dbc600e1d7256e2a9f90c9a3e05870" size="155830642">
      http://124.232.132.18/mp4/021/170/065/21170065.f4v?key=1d0399b5a9fa36b8b7f8004a21a241cb4054c3
    </f>
    <f w="1" h="0" sha1="5aa07d5920dbc600e1d7256e2a9f90c9a3e05870" size="155830642">
      http://218.61.197.4/mp4/021/170/065/21170065.f4v?key=1d0399b5a9fa36b8b7f8004a21a241cb4054c3
    </f>
    <f w="1" h="0" sha1="5aa07d5920dbc600e1d7256e2a9f90c9a3e05870" size="155830642">
      http://125.211.196.4/mp4/021/170/065/21170065.f4v?key=1d0399b5a9fa36b8b7f8004a21a241cb4054c3
    </f>
    <f w="1" h="0" sha1="b79b115953b0b999c836f294abfb1a47dc6c714a" size="107871014">
      http://124.232.132.2/m4v/021/170/065/21170065.m4v?key=eaf4b1b43c1f371d7a4cb64a21a241cb4054c3
    </f>
    <f w="1" h="0" sha1="b79b115953b0b999c836f294abfb1a47dc6c714a" size="107871014">
      http://121.12.103.44/m4v/021/170/065/21170065.m4v?key=eaf4b1b43c1f371d7a4cb64a21a241cb4054c3
    </f>
    <f w="1" h="0" sha1="b79b115953b0b999c836f294abfb1a47dc6c714a" size="107871014">
      http://123.134.67.68/m4v/021/170/065/21170065.m4v?key=eaf4b1b43c1f371d7a4cb64a21a241cb4054c3
    </f>
    <f w="1" h="0" sha1="b79b115953b0b999c836f294abfb1a47dc6c714a" size="107871014">
      http://125.211.196.5/m4v/021/170/065/21170065.m4v?key=eaf4b1b43c1f371d7a4cb64a21a241cb4054c3
    </f>
    <f w="1" h="0" sha1="b79b115953b0b999c836f294abfb1a47dc6c714a" size="107871014">
      http://218.61.197.5/m4v/021/170/065/21170065.m4v?key=eaf4b1b43c1f371d7a4cb64a21a241cb4054c3
    </f>
  </b>
</v>
=cut

  # Force the 'f' tag to be always parsed as a multi-element
  # even when there is only one element
  my $xml = from_xml($raw_xml, forcearray => [ 'f' ] );

  # The video is usually available on multiple servers
  # and sometimes in multiple video formats
  my %streams;
  foreach my $file ( @{$xml->{b}->{f}} )
  {
    my $url = $file->{content};

    # Attempt to extract file format
    my ( $format ) = ( $url =~ m`http://[^/]+/([^/]+)/` );
    debug "Unable to extract file format for $url" and next
      unless $format;

    push @{$streams{$format}{urls}}, $url;
    $streams{$format}{size} = $file->{size};
  }

  # Acceptable streams (in preferred order): mp4, m4v, flv, phoneMp4
  my $stream
    = ( exists $streams{mp4} ? 'mp4'
      : exists $streams{m4v} ? 'm4v'
      : exists $streams{flv} ? 'flv'
      : exists $streams{wwwFlv} ? 'wwwFlv'
      : exists $streams{f4v} ? 'f4v'
      : exists $streams{phoneMp4} ? 'phoneMp4'
      : '' );

  my $stream_formats = join ', ', ( keys %streams );
  die "Video is only available in unknown file formats ($stream_formats)",
    unless $stream;

  # Choose random server to download from
  debug "Choosing to use the $stream stream (available: $stream_formats)";
  my $stream_choice = int rand( 1 + $#{$streams{$stream}{urls}} );
  my $url = @{$streams{$stream}{urls}}[$stream_choice];

  # Source ID, this identifies where the request is coming from
  my $sourceID = ( $stream eq 'flv' ? '11000' : '18000' );
  $url =~ s/\?key=/?$sourceID&key=/;

  # Use the video title as the filename when available; always use flv
  # file extension though as no matter what stream format we choose, it
  # is still wrapped inside an flv video container
  my $title = $xml->{title};
  my $filename = title_to_filename( $title, 'flv' );

  my $stream_duration = $xml->{time};
  my $stream_size = $streams{$stream}{size};
  debug sprintf
    "%s, %d seconds, %s bytes",
    $title, $stream_duration / 1000, $stream_size
      if ( $title and $stream_duration and $stream_size );

  return ( $url, $filename );
}

1;
