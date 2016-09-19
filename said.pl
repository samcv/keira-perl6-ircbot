#!/usr/bin/env perl
# said perlbot script
use strict;
use warnings;
use LWP::Simple;
use URI::Find;
use HTML::Entities;
use feature 'unicode_strings';
use utf8;
our $VERSION = 0.2;

my($who_said, $body, $username) = @ARGV;

my $max_title_length = 120;

#START
#END

my $line_no          =  1;
my $is_text          =  0;
my $end_of_header    =  0;

my $title            = -1;
my @curl_title;
my $curl_max_time    =  5;
my $title_start_line = -1;
my $title_end_line   = -1;
my $url              = '%';

my $cloudflare        = 0;
my $has_cookie        = 0;
my $is_404            = 0;
my $error_line        = 0;
my $new_location_text = q();
my $new_location      = q(%);

my $history_file;
my $new_history_file;
my $bak_history_file;
my $history_file_length;

if( ($body eq "") and ($who_said eq "") ) {
	print "Did not receive any input\n";
	print "Usage: said.pl nickname \"text\" botname\n";
	exit 1;
}
# Trunicate history file only if the bot's username is set.
if ($username ne "") {
	$history_file     = $username . '_history.txt';
	$new_history_file = $username . '_history.new.txt';
	$bak_history_file = $username . '_history.bak.txt';
	$history_file_length = 20;

	`tail -n $history_file_length ./$history_file | sponge ./$history_file` and print "Problem with tail $history_file > $new_history_file, Error $?\n";
}

sub get_url {
	$url = shift @_;
	if ($url eq '%') {
		return;
	}
	open( my $CURL_OUT, "-|", "curl --compressed -A \"Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/53.0.2785.116 Safari/537.36\" --max-time $curl_max_time --no-buffer -v --url \"$url\" 2>&1" );

	while  ( defined (my $line = <$CURL_OUT>) ) {
		# Detect end of header
		if ( ( $line =~ /^<\s*$/) && ($end_of_header == 0) ) {
			$end_of_header = 1;
			print "end of header detected\n";
			if($is_text == 0) {
				print "Stopping because it's not text\n";
				close $CURL_OUT;
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
		if ( ($end_of_header == 1) && ($line =~ s/.*<title>\s?//i  ) ) {
			$title_start_line = $line_no;
			# If the line is empty don't push it to the array
			if ( $line =~ /^\s*$/) {
			}
			else {
				push @curl_title, $line;
			}
		}

		if ( ($end_of_header == 1) && ($line =~ s/\s*<\/title>.*//i) ) {
			$title_end_line   = $line_no;
			# If <title> and </title> are on the same line, just set that one line to the aray
			if ($title_end_line == $title_start_line) {
				$curl_title[0] = $line;
				last;
			}
			# If the line is empty don't push it to the array
			if ( $line =~ /^\s*$/) {
			}
			else {
				push @curl_title, $line;
			}
			last;
		}
		# If we are between <title> and </title>, push it to the array
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
	if ( ($title_start_line != -1) or ($title_end_line != 1) ) {
		print '$title_start_line = ' . "$title_start_line  " . '$title_end_line = ' . $title_end_line . "\n";
	}
	else {
		print "No title found, searched $line_no lines\n";
	}

	close($CURL_OUT);
	if ($new_location ne '%') {
		return 1;
	}

}



# .bots reporting functionality
if ( $body =~ /[.]bots.*/xms ) {
	print "%$username reporting in! [perl] $repo_url v$VERSION\n";
}
#START
#END

# Sed functionality. Only called if the bot's username is set and it can know what history file
# to use.
elsif ( ($body =~ m|^s/.+/| ) and ($username ne "") ) {
	my $first = $body;
	$first =~ s|^s/(.+)/.*|$1|;
	print "first: $first\n";
	my $second = $body;
	$second =~ s|^s/.+/(.*)|$1|;
	print "second: $second\n";
	my $replaced_who;
	my $replaced_said;
	print "Trying to open $history_file\n";
	open my $history_fh, '<', "$history_file" or print "Could not open $history_file\n";
	while  ( defined (my $history_line = <$history_fh>) ) {
		chomp $history_line;
		print "$history_line\n";
		my $history_who = $history_line;
		$history_who =~ s|^<(.+)>.*|$1|;
		#print "history_who : $history_who\n";
		my $history_said = $history_line;
		$history_said =~ s/<.+> //;
		#print "history_said: $history_said\n";
		if (($history_said =~ m/$first/i) && ($history_said !~ m|^s/| )){
			print "Found match\n";
			$replaced_said = $history_said;
			$replaced_said =~ s|$first|$second|ig;
			$replaced_who = $history_who;
			print "replaced_said: $replaced_said\n";
		}
	}
	close $history_fh;
	if ($replaced_said ne "") {
		print "%<$replaced_who> $replaced_said\n";
	}
	exit 0;
}

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
		@curl_title       = ();
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
			$title = join (" ", @curl_title);
			print "$title  url is\n";
		}

		chomp $title;
		if ( !$title ) {
			print "No title found\n";
			exit;
		}

		# Remove starting whitespace
		$title =~ s/^\s*//xmsg;
		# Remove ending whitespace
		$title =~s/\s*$//g;
		# Replace carriage returns with two spaces
		$title =~ s/\r/ /xmsg;
		# Decode html entities such as &nbsp
		$title = decode_entities($title);
		my $short_title = substr $title, 0, $max_title_length;
		if ( ( $title ne $short_title ) and ( $url !~ m|twitter[.]com/.+/status| ) ) {
			$title = $short_title . ' ...';
		}
		if ( !$title ) {
			print "No title found right before print\n";
			exit;
		}

		if ( $new_location ne q(%) ) {
			$new_location_text = " >> $new_location";
			chomp $new_location_text;
		}
		else {
			$new_location_text = q();
		}

		print "%[ $title ]" . $new_location_text . $cloudflare_text . $cookie_text . "\n";
	}
	else {
		exit;
	}
