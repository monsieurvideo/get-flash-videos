package FlashVideo::Site::Youku;

use strict;
use FlashVideo::Utils;

# This was way too much work; breaking the encryption was a pain in the ass
sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my $check_response = sub {
    my ( $message ) = @_;
    return if $browser->success;
    die sprintf $message, $browser->response->code;
  };

  # Watch: http://v.youku.com/v_show/id_XOTA4ODg2NTI=.html
  # Embed: http://player.youku.com/player.php/sid/XOTA4ODg2NTI=/v.swf
  # which redirects to:
  #        http://static.youku.com/v1.0.0036/v/swf/qplayer.swf?VideoIDS=XOTA4ODg2NTI=&embedid=-&showAd=0

  if ( $embed_url !~ m`^http://v.youku.com/v_show/` )
  {
    # Not quite the URL we expect, maybe it's the embedded one?
    die "Don't recognise the youku link"
      unless $embed_url =~ m`player.php/sid/(.+)/v\.swf`
      or $embed_url =~ m`qplayer\.swf\?VideoIDS=([^&]+)`;

    $embed_url = sprintf "http://v.youku.com/v_show/id_%s.html", $1;
    $browser->get( $embed_url );
  }
  $check_response->( "Can't load the youku page, server response was %s" );

  # There is a JS variable we need to scan for to get the internal video ID
  my ( $videoID ) = ( $browser->content =~ /var videoId = '(.+?)';/ );
  die "Couldn't extract video ID from youku page, we are probably out of date"
    unless $videoID;
  debug "Using video ID $videoID";

  # Need to get information about the video
  $browser->get(
    sprintf "http://v.youku.com/player/getPlayList/VideoIDS/%s/version/5/source/video/password/?ran=%d&n=%d",
    $videoID, rand( 10000 ), 3 );
  $check_response->( "Couldn't grab video informaton from youku, server response was %s" );

  # Response is a JSON data structure
  return parse_video_info( $browser, $browser->content );  
}

# The JSON video info hash has everything we need
sub parse_video_info {
  my ( $browser, $json ) = @_;
  debug "Video data: $json";

=begin
JSON structure:
{
    "data": [
    {
        "tt": "0",
        "ct": "f",
        "cs": "2128",
        "logo": "http:\/\/vimg8.yoqoo.com\/1100641F464A093EE7A01B012D4F1E594631EE-7D79-6FCE-936E-FDB651BA15F1",
        "seed": 1291,
        "tags": [ "\u97f3\u4e50", "\u56db\u5ddd", "\u5730\u9707", "\u7eaa\u5ff5", "\u8001\u5916", "\u5468\u5e74", "\u707e\u533a", "MV", "music", "Video" ],
        "categories": "95",
        "streamsizes": { "flv": "4840977" },
        "streamfileids": { "flv": "16*18*16*16*43*4*16*25*16*16*4*27*16*39*41*5*5*59*27*4*59*41*16*25*18*63*4*64*25*5*4*27*41*63*25*41*5*6*24*39*16*19*54*24*4*63*25*27*24*16*41*41*33*24*64*25*5*6*43*16*6*41*27*41*25*18*"},
        "videoid": "22722163",
        "segs":
        {
            "flv": [
            {
                "no": "0",
                "size": "4840977",
                "seconds": "145"
            } ]
        },
        "fileid": "16*18*16*16*43*4*16*25*16*16*4*27*16*39*41*5*5*59*27*4*59*41*16*25*18*63*4*64*25*5*4*27*41*63*25*41*5*6*24*39*16*19*54*24*4*63*25*27*24*16*41*41*33*24*64*25*5*6*43*16*6*41*27*41*25*18*",
        "username": "YBuzz",
        "userid": "19746590",
        "title": "MV: \u6765\u81ea\u56db\u5ddd\u7684\u6b4c\u58f0",
        "key1": "a4156bcd",
        "key2": "df891d4af342844b",
        "seconds": "145.40",
        "streamtypes": [ "flv" ]
    } ],
    "user": { "id": 0 },
    "controller": { "search_count": true }
}
=cut

  my ( $shuffle_seed ) = ( $json =~ /"seed":(\d+)/ );
  die "Can't find the seed value in the video info JSON"
    unless $shuffle_seed;

  # Sometimes, the video has a HQ version in mp4 format
  my ( $streams ) = ( $json =~ /"streamtypes":\[([^\]]+)\]/ );
  my $stream = ( index $streams, 'mp4' ) > 0 ? 'mp4' : 'flv';
  debug "Choosing to use the $stream stream (available: $streams)";

  # Use the file ID associate with the stream we choose when available
  my $fileID = '';
  if ($json =~ /"streamfileids":{([^}]+)}/) {
    my $streamfileids = $1;
    ( $fileID ) = ( $streamfileids =~ /"$stream":"([^"]+)"/ );
  }
  ( $fileID ) = ( $json =~ /"fileid":"([^"]+)"/ ) if not $fileID;
  die "Can't find the encrypted file ID in the video info JSON"
    unless $fileID;
  debug "Encrypted file ID: $fileID";

  # File ID is given in obfuscated form, each entry is an index in a lookup
  # table that is generated from the seed value
  my @lookup_table = shuffle_table( $shuffle_seed );
  $fileID =~ s/(\d+)\*/$lookup_table[$1]/eg;
  debug "Decrypted file ID: $fileID (seed is $shuffle_seed)";

  # Session ID seems to be just the Unix time + '1' + 7 random digits,
  # the _00 part seems to mean something that I can't figure out
  my $sID = sprintf "%s1%07d_00", time, rand( 10000000 ) ;

  # Now these are funky
  my ( $keyA ) = ( $json =~ /"key1":"([^"]+)"/ );
  my ( $keyB ) = ( $json =~ /"key2":"([^"]+)"/ );
  my $key = sprintf "%s%x", $keyB, hex( $keyA ) ^ hex( 'a55aa5a5' );

  # Video title is in escaped unicode format
  my ( $title ) = ( $json =~ /"title":"([^"]+)"/ );
  $title =~ s/\\u([a-f0-9]{4})/chr(hex $1)/egi;

  # Use the video title as the filename when available
  my $filename = get_video_filename( $stream );
  $filename = title_to_filename( $title, $stream ) if $title;

  my ( $stream_info ) = ( $json =~ /"segs":{"$stream":\[([^\]]+)\]/ );
  my @urls;
  my $part_count = 0;

  while ($stream_info =~ /\G{"no":"?(\d+)"?,([^}]+)},?/g) {
    my ( $segment_number, $segment_info ) = ( $1, $2 );
    my ( $segment_duration ) = ( $segment_info =~ /"seconds":"([^"]+)"/ );
    my ( $segment_size ) = ( $segment_info =~ /"size":"([^"]+)"/ );

    # To download segments other than the first (00), we replace
    # the digits at position 8 in the file ID with the segment
    # number as a two digit upper-case hexidecimal
    my $segment_number_str = sprintf '%02X', $segment_number;
    my $segment_fileID = $fileID;
    substr $segment_fileID, 8, 2, $segment_number_str;

    # Combine it all for the request to grab the video link for this segment
    $browser->get(
      sprintf "http://f.youku.com/player/getFlvPath/sid/%s/st/%s/fileid/%s?K=%s&myp=null",
        $sID, $stream, $segment_fileID, $key );

    # If we're successful, we should get a 302 with the location of the segment
    my $url = $browser->response->header( 'Location' );
    die "Youku rejected our attempt to get the video, we're probably out of date"
      unless $browser->response->code eq 302 and $url;

    # Sometimes, for whatever reason, the location we get back is missing
    # the file extension
    debug "Video location for segment $segment_number is $url";
    $url = "$url.$stream" unless $url =~ /$stream$/;

    debug sprintf
      "%s, segment %d, %s seconds, %s bytes",
      $title, $segment_number, $segment_duration, $segment_size
        if ( $title and $segment_duration and $segment_size );

    push @urls, [$url, ++$part_count, 0, $segment_size];
  }

  $_->[2] = $part_count for @urls;

  return ( \@urls, $filename );
}

# Modified Fisher-Yates shuffle
sub shuffle_table {
  my ( $seed ) = @_;
  my @lookup
    = split //,
      q`abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ/\:._-1234567890`;

  my @shuffled;
  while ( $#lookup > 0 )
  {
    # PRNG is a standard linear congruential generator
    # with a = 211, c = 30031, and m = 2^16
    $seed = ( 211 * $seed + 30031 ) % 2**16;

    # i.e. move a randomly chosen character from the source
    # deck onto the end of the shuffled deck
    my $x = int( $seed / 2**16 * ( $#lookup + 1 ) );
    push @shuffled, splice( @lookup, $x, 1 );
  }
  return @shuffled;
}

1;
