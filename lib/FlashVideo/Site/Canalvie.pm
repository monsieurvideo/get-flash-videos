#############################################################################
#	Canalvie.pm												2010-11-25
#
#	Reverse-engineered using URLSnooper v2.28.01 & WinPcap 4.1.2
#
#	Stavr0
#
#
{
package FlashVideo::Site::Canalvie;

use strict;
BEGIN { FlashVideo::Utils->import(); } # (added by utils/combine-perl.pl)
BEGIN { no strict 'refs';  *title_to_filename = \&FlashVideo::Utils::title_to_filename; *from_xml = \&FlashVideo::Utils::from_xml; }

sub find_video {
  my($self, $browser, $embed_url, $prefs) = @_;

  my $check_response = sub {
    my ( $message ) = @_;
    return if $browser->success;
    die sprintf $message, $browser->response->code;
  };


  my $videoID = 0;

  ( $videoID ) = ( $browser->content =~ /var\s+videoId\s*=\s*(\d+)\s*;/ );
  debug "VIDEOID = " . $videoID;
  
  die "No Canalvie Video ID found" unless  $videoID;
  
  my $title;
  ( $title ) = ( $browser->content =~ /NOM EPISODE\+LIEN ici --><a [^>]+>([^<]+)/ );
  debug "TITLE = " . $title . " " . title_to_filename($title, 'flv');
 
  my $xmlurl = 'http://www.canalvie.com/webtele/_dyn/getVideoDataXml.jsp?videoId=' . $videoID;
  $browser->get($xmlurl);
  my $xml = from_xml($browser);
  
  my $url;
  if ( $prefs->{quality} == "high" ) {
	$url = $xml->{video}->{highFlvUrl};
  } else {		
  	$url = $xml->{video}->{lowFlvUrl};
  }
  debug "URL = " . $url;
  
  my $ext;
  ( $ext ) = ( $url =~ /\.(.+)$/ );

  die "No (high|low)FlvUrl found in XML ". $xmlurl unless $url;
  
  return $url, title_to_filename($title, $ext);
  
 }


1;
}