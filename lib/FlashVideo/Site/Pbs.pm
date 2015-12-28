# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Pbs;

use strict;
use warnings;
use FlashVideo::Utils;
use FlashVideo::JSON;

=pod

Programs that work:
    - http://video.pbs.org/video/1623753774/
    - http://www.pbs.org/video/2365612568/
    - http://www.pbs.org/wnet/nature/episodes/revealing-the-leopard/full-episode/6084/
    - http://www.pbs.org/wgbh/nova/ancient/secrets-stonehenge.html
    - http://www.pbs.org/wnet/americanmasters/episodes/lennonyc/outtakes-jack-douglas/1718/
    - http://www.pbs.org/wnet/need-to-know/video/need-to-know-november-19-2010/5189/
    - http://www.pbs.org/newshour/bb/transportation/july-dec10/airport_11-22.html

Programs that don't work yet:
    - http://www.pbs.org/wgbh/pages/frontline/woundedplatoon/view/
    - http://www.pbs.org/wgbh/roadshow/rmw/RMW-003_200904F02.html

TODO:
    - subtitles

=cut

our $VERSION = '0.03';
sub Version() { $VERSION; }

sub find_video {
  my ($self, $browser, $embed_url, $prefs) = @_;

  my ($media_id) = $embed_url =~ m[http://(?:video|www)\.pbs\.org/videoPlayerInfo/(\d+)]x;
  unless (defined $media_id) {
    ($media_id) = $browser->uri->as_string =~ m[
      ^http://(?:video|www)\.pbs\.org/video/(\d+)
    ]x;
  }
  unless (defined $media_id) {
    ($media_id) = $browser->content =~ m[
      http://(?:video|www)\.pbs\.org/widget/partnerplayer/(\d+)
    ]x;
  }
  unless (defined $media_id) {
    ($media_id) = $browser->content =~ m[
      /embed-player[^"]+\bepisodemediaid=(\d+)
    ]x;
  }
  unless (defined $media_id) {
    ($media_id) = $browser->content =~ m[var videoUrl = "([^"]+)"];
  }
  unless (defined $media_id) {
    ($media_id) = $browser->content =~ m[pbs_video_id_\S+" value="([^"]+)"];
  }
  unless (defined $media_id) {
    my ($pap_id, $youtube_id) = $browser->content =~ m[
      \bDetectFlashDecision\ \('([^']+)',\ '([^']+)'\);
    ]x;
    if ($youtube_id) {
      debug "Youtube ID found, delegating to Youtube plugin\n";
      my $url = "http://www.youtube.com/v/$youtube_id";
      require FlashVideo::Site::Youtube;
      return FlashVideo::Site::Youtube->find_video($browser, $url, $prefs);
    }
  }
  die "Couldn't find media_id\n" unless defined $media_id;
  debug "media_id: $media_id\n";
  
  # pbs.org uses redirects all over the place
  $browser->allow_redirects;
  
  my $account = $prefs->account("pbs.org", <<EOT);
If you set up a PBS account, you can access high definition videos.
The pbs.org login is the email address you registered at pbs.org.
See the documentation, i.e man netrc, for how to configure ~/.netrc
and skip continual prompting for account credentials. Example:
   machine pbs.org
   login myemail\@xyzzy.net
   password xxxxxxx
NOTE: if the login is set to 'no', standard definition will be downloaded.

EOT

  my $query = 'http://player.pbs.org/videoInfo/' . $media_id;

  if ($account->username and $account->username ne 'no' and $account->password) {
   # get the pbs.ord login page and fill in the login form
   $browser->get('https://account.pbs.org/oauth2/authorize/?scope=account&redirect_uri=http://www.pbs.org/login/&response_type=code&client_id=LXLFIaXOVDsfS850bnvsxdcLKlvLStjRBoBWbFRE');
   die "Could not access login page" unless $browser->success();
   
   # fill in the login form with the users credentials
   $browser->form_number(1);
   $browser->field('email', $account->username);
   $browser->field('password', $account->password);
   
   # submit the login request
   $browser->submit();
   if ($browser->success()) {
   
      # login successful, but need to extract some cookie values to retrieve
      # high definition video
      my $pbs_uid;
      my $pbs_station;
   
      foreach my $cookie (split /\n/, $browser->cookie_jar->as_string()) {
         my @tokens = split /; |: /, $cookie;
         my ($cname, $cvalue) = split /=/, $tokens[1];
         $pbs_uid = $cvalue if $cname eq 'pbs_uid';
         $pbs_station = $cvalue if $cname eq 'pbsol.station';
         debug "cookie name = $cname, value = $cvalue"
      }
   
      debug "setting pbs_uid=$pbs_uid and callsign=$pbs_station";
      info "using pbs.org account " . $account->username . " to retrieve high definition videos";
      # format query to get high definition video details in JSON
      $query = $query . '/?callsign=' . $pbs_station . '&uid=' . $pbs_uid . '&callback=video_info&format=jsonp&type=portal';
      
      } else {
         info "\n*** pbs.org login failed ***\ncorrect your login and password\nwill retrieve standard definition video.\n";
         # format query to get standard definition video details in JSON
         $query = $query . '/?callsign=KCTS&callback=video_info&format=jsonp&type=portal';
      }
   
  } else {
   info "no pbs login credentials, will retrieve standard definition video.";
   # format query to get standard definition video details in JSON
   $query = $query . '/?callsign=KCTS&callback=video_info&format=jsonp&type=portal';
  }
  
  info "Downloading video metadata";
  $browser->get($query);
  die "Could not get video metadata" unless $browser->success();
  
  # Content is JSON fomatted
  my $result = from_json($browser->content());
  
  # Get the video's title and urs source
  my $title = $result->{title};
  die "Could not extract video title" unless $title;
  debug "title is: $title\n";
  
  my $urs = $result->{recommended_encoding}->{url};
  die "Could not extract video urs" unless $urs;
  debug "urs extracted\n";
  
  # format another query to get video url in JSON  
  $query = $urs . '?format=json';
  
  info "Downloading video details";
  $browser->get($query);
  die "Could not get video details" unless $browser->success();
  
  # Content is JSON fomatted
  $result = from_json($browser->content());
  
  # Get the video's url source
  my $url = $result->{url};
  die "Could not extract video url" unless $url;
  debug "found PBS video: $media_id @ $url";
  
  # get the scheme and filetype to determine appropriate downloader
  my ($scheme, $filetype) = $url =~ m[(^\w+):.*\.(\w+)$];
     debug "scheme is: $scheme";
     debug "file type is: $filetype";  
  
  if ($scheme =~ m[^rtmp]) {
  # pbs.org has not moved all videos from flash to hls
  # use rtmpdump for backward compatibility
     my $playpath;
     ($playpath) = $url =~ m[(\w+:*:videos.*$)];
     debug "playpath is: $playpath";
     debug "using rtmp downloader";
     return {
       rtmp    => $url,
       playpath => $playpath,
       flashVer => 'LNX 11,2,202,481',
       flv     => title_to_filename($title, $filetype),
     };
  } elsif ($scheme =~ m[^http] and $filetype eq "m3u8") {
      debug "using hls downloader";
      return {
         downloader => "hls",
         flv        => title_to_filename($title, "mp4"),
         args       => { hls_url => $url, prefs => $prefs }
      };
  } elsif ($scheme =~ m[^http] and $filetype eq "mp4") {
      return $url, title_to_filename($title, $filetype);
  } else {
      die "Video is in unknown scheme or format. Run with debug and report problem";
  }
}

1;
