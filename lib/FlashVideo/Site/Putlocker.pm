# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Putlocker;

use strict;
use FlashVideo::Utils;
use HTML::Tree;
use HTML::Entities qw(decode_entities);

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;

  die 'Could not retrieve video' unless ($browser->success);

  my ($id) = ($embed_url =~ m,file/([^/]*),);
  print $id,"\n";

  my ($filename) = title_to_filename(extract_title($browser));
  $filename =~ s/[\s\|_]*PutLocker[\s_]*//;
  my $url; # the final URL
  
  #get the "hash" value from the HTML
  my $tree = HTML::Tree->new();
  $tree->parse($browser->content);
  my $hash = $tree->look_down( 'name' , 'hash' )->attr('value');
  info 'Found hash: ' . $hash;
  
  #Construct a POST request to get the tell the server to serve real page content
  info "Confirming request to PutLocker.";
  
  $browser->add_header( 'Content-Type' => 'application/x-www-form-urlencoded' );
  $browser->add_header( 'Accept-Encoding' => 'text/html' );
  $browser->add_header( Referer => $embed_url );
  
  my $response = $browser->post($embed_url,
    [ 'confirm'=>"Continue as Free User",
      'hash'=>$hash
      ]);

  # request is successful - die if not
  die 'Request not successful' unless ($browser->success);
  
  my $page_html = $response->content;
  
  #the stream ID is now embedded in the page.
  my ($streamID) = ($page_html =~ /get_file\.php\?stream=([A-Za-z0-9=]+)/);
  info "Found the stream ID: " . $streamID;
  
  #request the url of the actual file
  my $uri = URI->new( "http://www.putlocker.com/get_file.php" );
  $uri->query_form((stream=>$streamID));

  #parse the url and title out of the response - much easier to regex it out, as the XML has dodgy &'s.
  $browser->allow_redirects;
  my $contents = $browser->get($uri)->content;
  # this is necessary to download both high quality and streaming version
  die 'Unable to download video information' unless ($browser->success);
  my ($stream_url) = ($contents =~ /url="(.*?)"/);
  $stream_url = decode_entities($stream_url);

  if($prefs->{quality} eq 'high') {
    $url = get_high_quality($id, $streamID);
  } else {
    # get streaming version
    $url = $stream_url;

    if($url =~ /expired_link/) {
      if( $page_html =~ m,"/(get_file\.php\?id=[^"]*)", ) {
        # download original file if link available
        my $download_page = $1;
        $url = URI->new( "http://www.putlocker.com/$1" );
        # this URL should be equivalent to what is returned by get_high_quality()
      }
    }
  }
  info "Got the video URL: " . $url;

  return $url, $filename;
}

sub get_high_quality {
  my ( $id, $key ) = @_;
  return "http://www.putlocker.com/get_file.php?id=$id&key=$key&original=1";
}

1;

