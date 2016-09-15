#!/usr/bin/env perl
# to try and get http headers with curl and extract the page title
# Takes one command line argument which is a URL
use strict;
use warnings;
use WWW::Curl::Easy;

my $url = $ARGV[0];
print "$url\n";
#open(my $STDOUT, "cat ./test.txt |" );
my $line_no          =  1;
my $is_text          =  0;
my $end_of_header    =  0;

my $title            = -1;
my $title_start_line = -1;
my $title_end_line   = -1;

my $new_location      = q(%);
my $new_location_text = q();

my $cloudflare        = 0;
my $has_cookie        = 0;
my $is_404            = 0;
my $error_line        = 0;
sub get_url {
	$url = shift @_;
	open( my $STDOUT, "-|", "curl --no-buffer -v --url $url 2>&1" );

	while  ( defined (my $line = <$STDOUT>) ) {
	#foreach my $line (<$STDOUT>) {
		#print $line;
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
			$has_cookie = 1;
			print "Cookie detected\n";
		}
		elsif ( $line =~ /^<\s*Location:\s*/xms ) {
			$new_location = $line;
			$new_location =~ s/^<\s*Location:\s*//ixms;
			$new_location =~ s/^\s+|\s+$//gxms;
			print "New Location: $new_location\n";
		}

		# Find the Title
		if ( ($end_of_header == 1) && ($line =~ /<title>/i  ) ) {
			# Print the line number
			#print line_indent($line_no) . $line_no . '
			$title            = $line;  chomp $title;
			$title_start_line = $line_no;
		}

		if ( ($end_of_header == 1) && ($line =~ /<\/title>/i) ) {
			$title            = $line;  chomp $title;
			$title_end_line   = $line_no;
			last;
		}

		$line_no = $line_no + 1;

	}

	# Print out $is_text and $title's values
	print '$is_text = ' . "$is_text\n";
	print '$title   = ' . "$title\n";
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
	else {
		return 0;
	}
}
if ( get_url($url) ) {
	get_url($new_location);
}

exit;
### This section of code also would wait until the entire file was downloading to begin doing anything
if ( $ARGV[1] eq "c" ) {
	my $curl = WWW::Curl::Easy->new;
	my $url = $1;
	$curl->setopt(CURLOPT_HEADER,1);
	$curl->setopt(CURLOPT_URL, $ARGV[0]);

	my $response_body;
	# Actually do the request
	my $retcode = $curl->perform;

	if ($retcode == 0) {
		print ("Transfer went ok\n");
		my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
		print ("Received response: $response_body\n");
	}
}
