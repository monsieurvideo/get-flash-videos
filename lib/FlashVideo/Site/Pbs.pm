# Part of get-flash-videos. See get_flash_videos for copyright.
package FlashVideo::Site::Pbs;

use strict;
use warnings;
use FlashVideo::Utils;
use FlashVideo::JSON;
use Data::Dumper;

=pod

Programs that work:
    - http://video.pbs.org/video/1623753774/
    - http://www.pbs.org/video/1623753774/
    - http://www.pbs.org/video/circus-born-to-be-circus/
    - http://www.pbs.org/video/2365612568/
    - http://www.pbs.org/video/american-experience-bonnie-clyde-preview/
    - http://www.pbs.org/show/tunnel/
    - http://www.pbs.org/show/remember-me/

Programs that don't work yet:
    - http://www.pbs.org/wgbh/pages/frontline/woundedplatoon/view/
    - http://www.pbs.org/wgbh/roadshow/rmw/RMW-003_200904F02.html

TODO:
    - subtitles

=cut

our $VERSION = '0.04';
sub Version() { $VERSION; }

sub find_video {
  our %opt;
  my ($self, $browser, $embed_url, $prefs) = @_;
  
  # check for redirect. PBS redirects old URLs to their most recent structures.
  my $status = $browser->status();
  if (($status >= 300) && ($status < 400)) {
    my $location = $browser->response()->header('Location');
    if (defined $location) {
      info "Redirected to $location\n";
      my $redirecturl = URI->new_abs($location, $browser->base());
      $browser->get($redirecturl);
        return $self->find_video($browser, $redirecturl, $prefs);
    }
  }

  # looking for the media ID which is needed to get the video player configuration
  my ($media_id) = $embed_url =~ m[http://(?:video|www)\.pbs\.org/videoPlayerInfo/(\d+)]x;
  debug("media id found in URL") if (defined $media_id);
  unless (defined $media_id) {
    debug("media id not found in URL");
    ($media_id) = $browser->uri->as_string =~ m[
      ^http://(?:video|www)\.pbs\.org/video/(.+)
    ]x;
    debug("media id found in URI") if (defined $media_id);
  }
  unless (defined $media_id) {
    debug("media id not found in URI");
    ($media_id) = $browser->content =~ m[
      http://(?:video|www)\.pbs\.org/widget/partnerplayer/(\d+)
    ]x;
    debug("media id found in partner player link") if (defined $media_id);
  }
  unless (defined $media_id) {
    debug("media id not found in partner player link");
    ($media_id) = $browser->content =~ m[
      /embed-player[^"]+\bepisodemediaid=(\d+)
    ]x;
    debug("media id found in embedded player reference") if (defined $media_id);
  }
  unless (defined $media_id) {
    debug("media id not found in embedded player reference");
    ($media_id) = $browser->content =~ m[var videoUrl = "([^"]+)"];
    debug("media id found in a pbs_video_id tag") if (defined $media_id);
  }
  unless (defined $media_id) {
    debug("media id not found in a javascript videoURL variable");
    ($media_id) = $browser->content =~ m[pbs_video_id_\S+" value="([^"]+)"];
    debug("media id found in a pbs_video_id tag") if (defined $media_id);
  }
  unless (defined $media_id) {
    debug("media id not found in a pbs_video_id tag");
    my ($pap_id, $youtube_id) = $browser->content =~ m[
      \bDetectFlashDecision\ \('([^']+)',\ '([^']+)'\);
    ]x;
    if ($youtube_id) {
      debug "Youtube ID found, delegating to Youtube plugin\n";
      my $url = "http://www.youtube.com/v/$youtube_id";
      require FlashVideo::Site::Youtube;
      return FlashVideo::Site::Youtube->find_video($browser, $url, $prefs);
    }
    debug("media id not found in a YouTube tag");
  }

  # pbs.org uses redirects all over the place
  $browser->allow_redirects;

  if (! defined $media_id) {
    debug ("...scanning for list of multiple videos");
  
    my @possible_videos = $browser->content =~ m{<a href=['"](/video/.+/)['"][^>]*>([^<]+)</a>}g;
    if (@possible_videos) {
      if (!$opt{yes}) {
        print "There are " . scalar(@possible_videos)/2 . " videos referenced, please choose:\n";
        my $count;
        for (my $i = 0; $i < $#possible_videos; $i += 2) {
          my $item = $i/2;
          my $item_title = $possible_videos[$i+1];
          # remove extraeous line feeds and white space
          $item_title =~ s/[\r\n]*//g;
          $item_title =~ s/^ *//;
          $item_title =~ s/ *$//;
          print "$item - $item_title\n";
        }

        print "\nWhich video would you like to use?: ";
        chomp(my $chosen_item = <STDIN>);    
        $chosen_item *= 2;
        if ($possible_videos[$chosen_item]) {
          my $chosen_url = "http://www.pbs.org" . $possible_videos[$chosen_item];
          $browser->get($chosen_url);
          return $self->find_video($browser, $chosen_url, $prefs);
        }
      }
      else
      {
        info "There were " . scalar(@possible_videos)/2 . " referenced videos, but you used the yes option.";
        info "Re-run without the yes option to select one.";
      }
    }
  }

  #
  die "Couldn't find media_id\n" unless defined $media_id;
  debug "media_id: $media_id\n";
  
  # PBS returns the player configuration as a javascript variable
  # extract the embedded javascript and extract the PBS.playerConfig variable
  my @scriptags =  $browser->content() =~/<script[^>]*>(.+?)<\/script>/sig;
  my $script;
  my $pbsdata;
  local $/ = "\r\n";
  foreach $script (@scriptags)
  {
     if ($script =~ /PBS.playerConfig/si) {
       ($pbsdata) = $script =~ /PBS.playerConfig += +([^;]*);/s;
       # change ' to " for the json parser
       $pbsdata =~ s/'/"/g;
       $pbsdata =~ s/([a-zA-Z_]+) *: /"$1" : /g;
       debug $pbsdata;
       last;
     }
  }
# Parse the json structure
  my $result = from_json($pbsdata);
  debug Data::Dumper::Dumper($result);
  die "Could not extract video player info.\n   Video may not be available.\n"
     unless ref($result) eq "HASH";
  
  # Get the video's id and the metadata source url and type
  my $video_id = $result->{id};
  die "Could not extract video id" unless $video_id;
  debug "video id is: $video_id\n";
  
  my $metaurl = $result->{embedURL};
  die "Could not extract video metadata source" unless $metaurl;
  debug "video metadata source is: $metaurl\n";
  
  my $metatype = $result->{embedType};
  die "Could not extract video metadata type" unless $metatype;
  debug "video metadata source is: $metatype\n";
  
  my $query = $metaurl . $metatype . $video_id;
 
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

  my $pbs_uid;
  my $pbs_station;

  # log into PBS if user has provided their credentials
  if ($account->username and $account->username ne 'no' and $account->password) {
   # get the pbs.ord login page and fill in the login form
   $browser->get('https://account.pbs.org/oauth2/authorize/?scope=account&redirect_uri=http://www.pbs.org/login/&response_type=code&client_id=LXLFIaXOVDsfS850bnvsxdcLKlvLStjRBoBWbFRE');
   if (! $browser->success()) {
     debug $browser->content();
     die "Could not access login page" unless $browser->success();
   }
   
   # fill in the login form with the users credentials
   $browser->form_number(1);
   $browser->field('email', $account->username);
   $browser->field('password', $account->password);
   
   # submit the login request
   $browser->submit();
   if ($browser->success()) {
   
      # login successful, but need to extract some cookie values to retrieve
      # high definition video
   
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
      $query = $query . '/?uid=' . $pbs_uid;
      
      } else {
         info "\n*** pbs.org login failed ***\ncorrect your login and password\nwill retrieve standard definition video.\n";
         # format query to get standard definition video details in JSON
         # $query = $query . '/?callsign=KCTS&callback=video_info&format=jsonp&type=portal';
      }
   
  } else {
   info "no pbs login credentials, will retrieve standard definition video.";
   # format query to get standard definition video details in JSON
   # $query = $query . '/?callsign=KCTS&callback=video_info&format=jsonp&type=portal';
  }
  
  info "Downloading video metadata";
  $browser->get($query);
  die "Could not get video metadata" unless $browser->success();
  
  # PBS returns the video metadata as a javascript variable
  # extract the embedded javascript and extract the PBS.videoData variable
  @scriptags =  $browser->content() =~/<script[^>]*>(.+?)<\/script>/sig;
  $script = "";
  $pbsdata = "";
  local $/ = "\r\n";
  foreach $script (@scriptags)
  {
     if ($script =~ /PBS.videoData/si) {
       ($pbsdata) = $script =~ /PBS.videoData += +([^;]*);/s;
       # change ' to " for the json parser
       $pbsdata =~ s/'/"/g;
       # PBS computes the number of chapters in the javascript.
       # We don't care, so replace it with an integer
       # so that the json parser does not fail.
       $pbsdata =~ s/: *chapters *,/: 4,/g;
       debug $pbsdata;
       last;
     }
  }
# Parse the json structure
  $result = from_json($pbsdata);
  debug Data::Dumper::Dumper($result);
  die "Could not extract video metadata.\n   Video may not be available.\n"
     unless ref($result) eq "HASH";
  
  # Get the video's title and urs source
  my $title = $result->{program}->{title} . " " . $result->{title};
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
  die "Could not extract video url. Possibly it is no longer available." unless $url;
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
