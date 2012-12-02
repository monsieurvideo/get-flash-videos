# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Putlocker;

use strict;
use FlashVideo::Utils;
use HTML::Tree;
use HTML::Entities qw(decode_entities);

sub find_video {
  my ($self, $browser, $embed_url) = @_;

  my ($filename) = title_to_filename(extract_title($browser));
  $filename =~ s/[\s\|_]*PutLocker[\s_]*//;
  
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
  die 'Response code was ' . $response->code . '. Should be 200.' unless ($response->code == '200');
  
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
  my ($url) = ($contents =~ /url="(.*?)"/);
  $url = decode_entities($url);

  info "Got the video URL: " . $url;

  return $url, $filename;
}

1;

