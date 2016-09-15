#!/usr/bin/env perl
# said perlbot script
use strict;
use warnings;
use LWP::Simple;
use URI::Find;
use WWW::Mechanize;
use WWW::Mechanize;
use feature 'unicode_strings';
use utf8;
our $VERSION = 0.1;

#START
#END

my $who_said = $ARGV[0];
my $body     = $ARGV[1];

#print "who: $who_said  body: $body \n";
my $last_line;        # FIXME
my $last_line_who;    # FIXME

# .bots reporting functionality
if ( $body =~ /[.]bots.*/xms ) {
	print "%$username reporting in! [perl] $repo_url version $VERSION\n";
}

# sed functionality
elsif ( $body =~ /^s\//xms ) {
	print "hit sed match\n";

	return;
	my $sed_line = $body;
	$sed_line =~ s/[\/]/#/xmsg;
	$sed_line =~ s/\$/\\\$/xmsg;
	$last_line =~ s/\$/\\\$/xmsg;
	print "env -i echo \"$last_line\" | env -i sed \"$sed_line\"";
	my $replaced_text = `env -i echo "$last_line" | env -i sed "$sed_line"`;
	chomp $replaced_text;
	$replaced_text =~ s/\n/ | /xmsg;

	if ( $replaced_text eq $last_line ) {
		return;
	}
	my $short_replaced_text = substr $replaced_text, 0, 200;
	if ( $replaced_text ne $short_replaced_text ) {
		$replaced_text = $short_replaced_text . ' ...';
	}

	print "<$last_line_who> $replaced_text\n", return;
}
$last_line     = $body;
$last_line_who = $who_said;

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
	if ( $url =~ m/;/xms ) {
		print "URL has comma(s) in it!\n";
		$url =~ s/;/%3B/xmsg;
		return;
	}
	if ( $url =~ m/\$/xms ) {
		print "\$ sign found\n";
		return;
	}

	#if($url =: m/.*:.*:.*:.*:.*:.*/) {
	#  print "IPv6 Address detected, adding brackets\n"
	#  $url =: m/.*:.*:.*:.*:.*:.*/

	#my $curl_text = `curl -I -L $url | egrep '^Content-Type' | grep -i text`;
	my @curl = `curl -g -N -I -L --connect-timeout 3 --url $url`;

	#print "curl: @curl\n";
	my $cloudflare        = 0;
	my $is_text           = 0;
	my $has_cookie        = 0;
	my $is_404            = 0;
	my $error_line        = 0;
	my $new_location_text = q();
	my $new_location      = q(%);

	foreach my $line (@curl) {
		if ( $line =~ /^CF-RAY:/ixms ) {
			$cloudflare = 1;
			print "Cloudflare = 1\n";
		}
		elsif ( $line =~ /^Content-Type.*text.*/ixms ) {
			$is_text = 1;
			print "Curl header says it's text\n";
		}
		elsif ( $line =~ /^Set-Cookie.*/ixms ) {
			$has_cookie = 1;
		}
		elsif ( $line =~ /^Location:/xms ) {
			$new_location = $line;
			$new_location =~ s/^Location: //ixms;
			$new_location =~ s/^\s+|\s+$//gxms;
		}

		#elsif ( $line =~ m/^HTTP.* 404/ ) {
		#    $is_404 = 1;
		#    $error_line = $line;
		#    chomp $error_line;
		#}
	}

	my $cloudflare_text = q();
	if ( $cloudflare == 1 ) {
		$cloudflare_text = ' **CLOUDFLARE**';
	}
	my $cookie_text = q();
	if ( $has_cookie == 1 ) {
		$cookie_text = q( ) . q(@);
	}
	if ($is_404) {
		print "# $error_line # " . $cookie_text . $cloudflare_text . "$url\n";
		return;
	}
	if ($is_text) {

		my $mech = WWW::Mechanize->new( timeout => 3 );
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
		$title =~ s/\n/ | /xmsg;

		#$title =~ s/&#/& #/g;
		$title =~ s/\r/ | /xmsg;
		my $short_title = substr $title, 0, 150;
		if ( $title ne $short_title ) {
			$title = $short_title . ' ...';
		}
		if ( !$title ) {
			print "No title found right before print\n";
			return;
		}

		if ( $new_location ne q(%) ) {
			$new_location_text = " >> $new_location";
			chomp $new_location_text;
		}
		else {
			$new_location_text = q();
		}

		print "%[ $title ]" . $new_location_text . $cloudflare_text . $cookie_text . "\n";
	}
	else {
		return;
	}

}
