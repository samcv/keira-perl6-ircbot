#!/usr/bin/env perl
# said perlbot script
use strict;
use warnings;
use WWW::Mechanize;
use URI::Find;
use LWP::Simple;
use WWW::Mechanize;
use feature 'unicode_strings';
use utf8;
our $VERSION = 0.1;


#START
#END

my $who_said = $ARGV[0];
my $body     = $ARGV[1];
#print "who: $who_said  body: $body \n";
my $last_line;     # FIXME
my $last_line_who; # FIXME

# .bots reporting functionality
if ( $body =~ /\.bots.*/ ) {
	print "%$username reporting in! [perl] $repo_url version $VERSION\n";
}
# sed functionality
elsif ( $body =~ /^s\// ) {
	print "hit sed match\n";
	return;
	my $sed_line = $body;
	$sed_line =~ s|/|#|g;
	$sed_line =~ s/\$/\\\$/g;
	$last_line =~ s/\$/\\\$/g;
	print "env -i echo \"$last_line\" | env -i sed \"$sed_line\"";
	my $replaced_text = `env -i echo "$last_line" | env -i sed "$sed_line"`;
	chomp $replaced_text;
	$replaced_text =~ s/\n/ | /g;
	if ($replaced_text eq $last_line) {
		return;
	}
	my $short_replaced_text = substr( $replaced_text, 0, 200 );
	if ( $replaced_text ne $short_replaced_text ) {
		$replaced_text = $short_replaced_text . " ...";
	}

	print "<$last_line_who> $replaced_text\n",
	return;
}
$last_line  = $body;
$last_line_who   = $who_said;

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
	my @curl = `curl -g -N -I -L --connect-timeout 3 --url $url`;

	#print "curl: @curl\n";
	my $cloudflare   = 0;
	my $is_text      = 0;
	my $has_cookie   = 0;
	my $is_404       = 0;
	my $error_line   = 0;
	my $new_location_text = "";
	my $new_location      = "%";

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
		elsif ( $line =~ /^Location:/ ) {
			$new_location = $line;
			$new_location =~ s/^Location: //i;
			chomp $new_location;
		}
		#elsif ( $line =~ m/^HTTP.* 404/ ) {
		#	$is_404 = 1;
		#	$error_line = $line;
		#	chomp $error_line;
		#}
	}

	my $cloudflare_text = "";
	if ( $cloudflare == 1 ) {
		$cloudflare_text = " **CLOUDFLARE**";
	}
	my $cookie_text = "";
	if ( $has_cookie == 1 ) {
		$cookie_text = " " . '@';
	}
	if ($is_404) {
		print "# $error_line # " . $cookie_text . $cloudflare_text . "$url\n";
		return;
	}
	if ($is_text) {

		my $mech = WWW::Mechanize->new(timeout => 3);
		$mech->get("$url");
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
		$title =~ s/\r/ | /g;
		my $short_title = substr( $title, 0, 150 );
		if ( $title ne $short_title ) {
			$title = $short_title . " ...";
		}
		if ( !$title ) {
			print "No title found right before print\n";
			return;
		}


		if ( $new_location ne "%" ) {
			$new_location_text = " >> $new_location";
		chomp $new_location_text;
		}
		else {
			$new_location_text = "";
		}


		print "%[ $title ]" . $new_location_text . $cloudflare_text . $cookie_text . "\n";
	}
	else {
		return;
	}

}
