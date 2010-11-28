# Author: paczesiowa@gmail.com
#
# This plugin works for videos from www.joemonster.org using 'Monster Player'
#
# Most (~70%) of them are single embedded youtube videos:
# http://www.joemonster.org/filmy/28773/Sposob_na_Euro_2012
# This plugin doesn't directly support them,
# so get_flash_videos fallbacks to youtube method, which works just fine.
# Pages with multiple youtube videos are also supported by youtube method,
# but only the first embedded video is downloaded:
# http://www.joemonster.org/filmy/4551/Terapia_masazem
#
# This plugin claims to support a page when it contains at least one video
# embedded with Monster Player.
# Pages with mixed providers, like this (Monster Player+youtube):
# http://www.joemonster.org/filmy/5496/Kolo_Smierci
# only downloads Monster Player movies, the rest is discarded,
# because I don't know how to provide links AND fallback to a different method.
#
# There are two versions of Monster Player:
# * old/fat
# http://www.joemonster.org/filmy/28784/Genialny_wystep_mlodego_iluzjonisty_w_Mam_talent (single video)
# http://www.joemonster.org/filmy/28693/Dave_Chappelle_w_San_Francisco_ (multi videos)
#
# * new/slim
# http://www.joemonster.org/filmy/28372/Wszyscy_kochamy_Polske_czesc_ (single video)
#
# Currently multiple videos are unsupported, only the first one is downloaded,
# I have no idea how to return multiple links
#
# About 5% of videos are embedded from external providers (different than youtube),
# they should work if get_flash_videos has appropriate method.

package FlashVideo::Site::Joemonster;

use strict;
use FlashVideo::Utils;
use URI::Escape;
use URI::QueryParam;

# Warning! This is the only perl code I've ever written.

# We have to find dummy embedded urls, that contain the real url in the file param of the dummy url
# e.g. <embed src="http://www.joemonster.org/flvplayer.swf?file=http%3A%2F%2Fdv.joemonster.org%2Fj%2FWszyscy_kochamy_Pols28372.flv&config=http://www.joemonster.org/mtvconfig.xml&image= http://www.joemonster.org/i/downth/th/p87612.jpg&recommendations=http://www.joemonster.org/download-related.php?lid=28372"
# regexen have to be escaped in strings:(
my $new_monster_player_regex = "<\\s*embed\\s*src\\s*=\\s*\"\\s*(http:\\/\\/www\\.joemonster\\.org\\/flvplayer\\.swf\\?file=.*?)\\s*\"";

sub is_new_monster_player {
    my($self, $browser) = @_;
    return $browser->content =~ m/$new_monster_player_regex/;
}

sub get_new_monster_player_url {
    my($self, $browser) = @_;
    $browser->content =~ m/$new_monster_player_regex/;
    return URI->new($1)->query_param('file') or die "no file key in player link";
}

# Old player is as easy to detect:
# e.g. <embed src="http://www.joemonster.org/emb/446297/Genialny_wystep_mlodego_iluzjonisty_w_Mam_talent/ex"
my $old_monster_player_regex = "<\\s*embed\\s*src\\s*=\\s*\"\\s*(http:\\/\\/www\\.joemonster\\.org\\/emb\\/.*?)\\s*\"";

sub is_old_monster_player {
    my($self, $browser) = @_;
    return $browser->content =~ m/$old_monster_player_regex/;
}

# But harder to download, matched url redirects to url, similar to what new player matches

sub get_old_monster_player_url {
    my($self, $browser) = @_;
    $browser->content =~ m/$old_monster_player_regex/;
    my $embedded_url = $1;
    $browser->get($embedded_url);
    my $url = $browser->uri;
    return URI->new($url)->query_param('file') or die "no file key in player link";
}

sub can_handle {
    my($self, $browser, $url) = @_;
    return $self->is_new_monster_player($browser) || $self->is_old_monster_player($browser);
}

sub find_video {
    my($self, $browser, $url) = @_;
    my $real_url;

    if ($self->is_new_monster_player($browser)) {
	$real_url = $self->get_new_monster_player_url($browser);
    }
    else {
	$real_url = $self->get_old_monster_player_url($browser);
    }

    my $title;
    if ($browser->title =~ m/(.*) - Joe Monster/ ) {
	$title = $1;
    } else {
	$title = $browser->title;
    }

    return $real_url, title_to_filename($title);
}

1;
