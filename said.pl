#!/usr/bin/env perl
# said perlbot script
use strict;
use warnings;
use LWP::Simple;
use URI::Find;
use feature 'unicode_strings';
use utf8;
our $VERSION = 0.2;


my $max_title_length = 120;
#START
#END

my $who_said = $ARGV[0];
my $body     = $ARGV[1];

my $line_no          =  1;
my $is_text          =  0;
my $end_of_header    =  0;

my $title            = -1;
my @curl_title;
my $title_start_line = -1;
my $title_end_line   = -1;
my $url              = '%';

my $cloudflare        = 0;
my $has_cookie        = 0;
my $is_404            = 0;
my $error_line        = 0;
my $new_location_text = q();
my $new_location      = q(%);


#print "who: $who_said  body: $body \n";
my $last_line;        # FIXME
my $last_line_who;    # FIXME
sub get_url {
	$url = shift @_;
	if ($url eq '%') {
		return;
	}
	open( my $STDOUT, "-|", "curl --max-time 5 --no-buffer -v --url $url 2>&1" );

	while  ( defined (my $line = <$STDOUT>) ) {
		# Detect end of header
		if ( ( $line =~ /^<\s*$/) && ($end_of_header == 0) ) {
			$end_of_header = 1;
			print "end of header detected\n";
			if($is_text == 0) {
				print "Stopping because it's not text\n";
				close $STDOUT;
				last;
			}
		}
		# Detect content type
		if ( ($line =~ /^<\s*Content-Type: text/i) && ($end_of_header == 0) ) {
			print "Curl header says it's text\n";
			$is_text = 1;
		}
		elsif ( $line =~ /^<\s*CF-RAY:/ixms ) {
			$cloudflare = 1;
			print "Cloudflare = 1\n";
		}
		elsif ( $line =~ /^<\s*Set-Cookie.*/ixms ) {
			$has_cookie++;
			print "Cookie detected\n";
		}
		elsif ( $line =~ /^<\s*Location:\s*/xms ) {
			$new_location = $line;
			$new_location =~ s/^<\s*Location:\s*//ixms;
			$new_location =~ s/^\s+|\s+$//gxms;
			print "New Location: $new_location\n";
		}

		# Find the Title
		if ( ($end_of_header == 1) && ($line =~ s/.*<title>//i  ) ) {
			# Print the line number
			#print line_indent($line_no) . $line_no . '
			push @curl_title, $line;
			$title_start_line = $line_no;
		}

		if ( ($end_of_header == 1) && ($line =~ s/<\/title>.*//i) ) {
			$title_end_line   = $line_no;
			if ($title_end_line == $title_start_line) {
				$curl_title[0] = $line;
				last;
			}
			push @curl_title, $line;
			last;
		}
		elsif ( ($end_of_header == 1) && ($title_start_line != -1 ) && ($title_start_line != $line_no ) ) {
			push @curl_title, $line;
		}


		$line_no = $line_no + 1;

	}
	# Print out $is_text and $title's values
	print '$is_text = ' . "$is_text\n";
	print '@curl_title   = ' . @curl_title . "\n";
	print '$end_of_header = ' . "$end_of_header\n";
	# If we found the header, print out what line it starts on
	if ( ($title_start_line != -1) || ($title_end_line != 1) ) {
		print '$title_start_line = ' . "$title_start_line  " . '$title_end_line = ' . $title_end_line . "\n";
	}
	else {
		print "No title found, searched $line_no lines\n";
	}

	close($STDOUT);
	if ($new_location ne '%') {
		return 1;
	}

}



# .bots reporting functionality
if ( $body =~ /[.]bots.*/xms ) {
	print "%$username reporting in! [perl] $repo_url version $VERSION\n";
}
#START
#END

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

print "Numfound: $num_found\n";
if ($num_found >= 1) {
	print "Number of URL's found $num_found \n";

	if ( $url eq '%' ) {
		print "Empty url found!\n";
		exit;
	}
	if ( $url =~ m/;/xms ) {
		print "URL has comma(s) in it!\n";
		$url =~ s/;/%3B/xmsg;
		exit;
	}
	if ( $url =~ m/\$/xms ) {
		print "\$ sign found\n";
		exit;
	}

	}
	if ( get_url($url) ) {
		@curl_title = ();
		$title_start_line = -1;
		$title_end_line   = -1;
		get_url($new_location);
		print $curl_title[0];
	}
	my $cloudflare_text = q();
	if ( $cloudflare == 1 ) {
		$cloudflare_text = ' **CLOUDFLARE**';
	}
	my $cookie_text = q();
	if ( $has_cookie >= 1 ) {
		$cookie_text = q( ) . q(@);
	}
	if ($is_404) {
		print "# $error_line # " . $cookie_text . $cloudflare_text . "$url\n";
		exit;
	}
	if ($is_text) {

		# Handle a multi line url
		my $title_length = @curl_title;
		print "Lines in title: $title_length\n";
		if ($title_length == 1) {
			$title = $curl_title[0];
		}
		else {
			$title = join (" | ", @curl_title);
			print "$title  url is\n";
		}

		chomp $title;
		if ( !$title ) {
			print "No title found\n";
			exit;
		}

		# Remove newlines and replace with a tab
		#$title =~ s/\n/ | /g;
		$title =~ s/\n/ | /xmsg;

		#$title =~ s/&#/& #/g;
		$title =~ s/\r/ | /xmsg;
		my $short_title = substr $title, 0, $max_title_length;
		if ( $title ne $short_title ) {
			$title = $short_title . ' ...';
		}
		if ( !$title ) {
			print "No title found right before print\n";
			exit;
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
		exit;
	}
