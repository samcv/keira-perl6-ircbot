#!/usr/bin/env perl
use strict;
use warnings;
use diagnostics;

package PerlBot;
use base qw(Bot::BasicBot);
use URI::Find;
use LWP::Simple;
use WWW::Mechanize my $ticked = 0;
# Debian package list:
# curl
# Debian perl package list:
# liburi-find-perl libpoe-component-sslify-perl libbot-basicbot-perl libwww-mechanize-perl
#START
#END
my $nick_name = $username;
my $alt_nickname_1 = $username . "-";
my $alt_nickname_2 = $username . "_";

my $repo_url = "<repo url>";


sub said {
	print "sub said Called\n";

	#&forkit();
	my $self    = shift;
	my $message = shift;
	my $body    = $message->{body};
	if ( $body =~ /\.bots.*/ ) {
		$self->say(
			{   channel => ( $self->channels ),    #[0],
				body => "$username reporting in! [perl] $repo_url\n",
			}
		);
		return;
	}
	elsif ( $body =~ /^s\// ) {
		print "hit sed match\n";
	}

	#exit if $ticked;
	my $url;
	my $req_url;
	my $finder = URI::Find->new(
		sub {
			my ( $uri, $orig_uri ) = @_;
			if ( head $uri) {
				print "$uri uri is okay\n";
			}
			else {
				print "$uri uri cannot be found\n";
				print "$orig_uri orig_uri cannot be found\n";

				#return;
			}
			$url = $orig_uri;
		}
	);

	my $num_found = $finder->find( \$body );

	#my $req_url = $url;
	#$req_url =~ s/;/%3B/g;
	#print $req_url . " " . $url . "\n";

	if ($num_found) {
		print "Number of URL's found $num_found \n";

		if ( !$url ) {
			print "Empty url found!\n";
			return;
		}
		$req_url = $url;
		if ( $url =~ m/;/ ) {
			print "URL has comma(s) in it!\n";
			$url =~ s/;/%3B/g;
			return;
		}
		if ( $url =~ m/\$/ ) {
			print "\$ sign found\n";
			return;
		}

		#if($url =: m/.*:.*:.*:.*:.*:.*/) {
		#  print "IPv6 Address detected, adding brackets\n"
		#  $url =: m/.*:.*:.*:.*:.*:.*/

		#my $curl_text = `curl -I -L $url | egrep '^Content-Type' | grep -i text`;
		my @curl = `curl -g -N -I -L --url $url`;

		#print "curl: @curl\n";
		my $cloudflare = 0;
		my $is_text    = 0;
		my $has_cookie = 0;
		my $is_404     = 0;
		my $error_line = 0;
		foreach my $line (@curl) {
			if ( $line =~ /^CF-RAY:/i ) {
				$cloudflare = 1;
				print "Cloudflare = 1\n";
			}
			elsif ( $line =~ /^Content-Type.*text.*/i ) {
				$is_text = 1;
				print "Curl header says it's text\n";
			}
			elsif ( $line =~ /^Set-Cookie.*/i ) {
				$has_cookie = 1;
			}
			elsif ( $line =~ /^HTTP\S+ 404/ ) {
				$is_404 = 1;
				$error_line = $line;
				chomp $error_line;
			}
		}

		my $cloudflare_text = "";
		if ( $cloudflare == 1 ) {
			$cloudflare_text = "**CLOUDFLARE** ";
		}
		my $cookie_text = "";
		if ( $has_cookie == 1 ) {
			$cookie_text = "@ ";
		}
		if ($is_404) {
			$self->say(
				{   channel => ( $self->channels ),    #[0],
					body => "# $error_line # " . $cookie_text . $cloudflare_text . "$url\n",
				}
			);
			return;
		}
		if ($is_text) {

			my $mech = WWW::Mechanize->new();
			$mech->get("$url") or return;
			if ( !$mech->is_html() ) {
				print "WWW::Mechanize says it's not html\n";
				return;
			}
			else {
				print "WWW::Mechanize says It's html\n";
			}
			my $title = $mech->title();

			chomp $title;
			if ( !$title ) {
				print "No title found\n";
				return;
			}

			# Remove newlines and replace with a tab
			#$title =~ s/\n/ | /g;
			$title =~ s/\n/ | /g;

			#$title =~ s/&#/& #/g;
			$title =~ s/\r/<CR>/g;
			my $short_title = substr( $title, 0, 70 );
			if ( $title ne $short_title ) {
				$title = $short_title . " ...";
			}
			if ( !$title ) {
				print "exiting line 52\n";
				return;
			}

			$self->say(
				{   channel => ( $self->channels ),    #[0],
					body => "[ $title ] " . $cookie_text . $cloudflare_text . "$url\n",
				}
			);
		}
		else {
			return;
		}

	}
	print "End of function\n";
	return;
}

### actual bot ###
PerlBot->new(
	server   => "$server_address",
	port     => "$server_port",
	channels => ["$server_channels"],

	nick      => "$nickname",
	alt_nicks => [ "$alt_nickname_1", "$alt_nickname_2" ],
	username  => "$username",
	name      => "$real_name",
	ssl       => 1
)->run();
