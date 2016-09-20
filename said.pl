#!/usr/bin/env perl
# said perlbot script
use strict;
use warnings;
use LWP::Simple;
use URI::Find;
use HTML::Entities;
use feature 'unicode_strings';
use utf8;
our $VERSION = 0.3;
my $repo_url = 'https://gitlab.com/samcv/perlbot';

my($who_said, $body, $username) = @ARGV;

my $history_file;

if( $body eq q() and $who_said eq q() ) {
	print "Did not receive any input\n";
	print "Usage: said.pl nickname \"text\" botname\n";
	exit 1;
}
# Trunicate history file only if the bot's username is set.
elsif ( $username ne q() ) {
	$history_file  = $username . '_history.txt';
	my $history_file_length = '20';

	`tail -n $history_file_length ./$history_file | sponge ./$history_file` and print "Problem with tail ./$history_file | sponge ./$history_file, Error $?\n";
}

sub sed_replace {
	my $first = $body;
	$first =~ s{^s/(.+)/.*}{$1};
	print "first: $first\n";
	my $second = $body;
	$second =~ s{^s/.+/(.*)}{$1};
	print "second: $second\n";
	my $replaced_who;
	my $replaced_said;
	print "Trying to open $history_file\n";
	open my $history_fh, '<', "$history_file" or print "Could not open $history_file\n";
	while  ( defined (my $history_line = <$history_fh>) ) {
		chomp $history_line;
		print "$history_line\n";
		my $history_who = $history_line;
		$history_who =~ s{^<(.+)>.*}{$1};
		my $history_said = $history_line;
		$history_said =~ s/<.+> //;
		if (($history_said =~ m/$first/i) && ($history_said !~ m{^s/} )){
			print "Found match\n";
			$replaced_said = $history_said;
			$replaced_said =~ s{\Q$first\E}{$second}ig;
			$replaced_who = $history_who;
			print "replaced_said: $replaced_said\n";
		}
	}
	close $history_fh;
	if ( $replaced_said ne q() ) {
		print "%<$replaced_who> $replaced_said\n";
	}
	exit 0;
}

sub get_url {
	my ($sub_url) = @_;

	my ($is_text, $end_of_header, $is_404, $has_cookie, $is_cloudflare) = ('0')  x '5';
	my ($title, $title_start_line, $title_end_line)                     = ('-1') x '3';
	my $line_no       =  1;

	my $new_location;
	my @curl_title;
	my $user_agent    = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/53.0.2785.116 Safari/537.36';
	my $curl_max_time =  '5';

	open my $CURL_OUT, '-|', "curl --compressed -A \"$user_agent\" --max-time $curl_max_time --no-buffer -v --url \"$sub_url\" 2>&1"
		or print "Could not open a pipe for curl\n" and return;

	while  ( defined (my $curl_line = <$CURL_OUT>) ) {
		# Detect end of header
		if ( ( $curl_line =~ /^<\s*$/) && ($end_of_header == 0) ) {
			$end_of_header = 1;
			print "end of header detected\n";
			if($is_text == 0) {
				print "Stopping because it's not text\n";
				close $CURL_OUT;
				last;
			}
		}
		# Detect content type
		if ( $curl_line =~ /^<\s*Content-Type: text/i and $end_of_header == 0 ) {
			print "Curl header says it's text\n";
			$is_text = 1;
		}
		elsif ( $curl_line =~ /^<\s*CF-RAY:/ixms ) {
			$is_cloudflare = 1;
			print "Cloudflare = 1\n";
		}
		elsif ( $curl_line =~ /^<\s*Set-Cookie.*/ixms ) {
			$has_cookie++;
		}
		elsif ( $curl_line =~ /^<\s*Location:\s*/ixms ) {
			$new_location = $curl_line;
			$new_location =~ s/^<\s*Location:\s*//ixms;
			$new_location =~ s/^\s+|\s+$//gxms;
			print "New Location: $new_location\n";
			last;
		}

		# Find the Title
		if ( $end_of_header == 1 and $curl_line =~ s/.*<title>\s?//i ) {
			$title_start_line = $line_no;
			# If the line is empty don't push it to the array
			if ( $curl_line =~ /^\s*$/) {
			}
			else {
				push @curl_title, $curl_line;
			}
		}

		if ( ($end_of_header == 1) && ($curl_line =~ s/\s*<\/title>.*//i) ) {
			$title_end_line   = $line_no;
			# If <title> and </title> are on the same line, just set that one line to the aray
			if ($title_end_line == $title_start_line) {
				$curl_title[0] = $curl_line;
				last;
			}
			# If the line is empty don't push it to the array
			if ( $curl_line =~ /^\s*$/) {
			}
			else {
				push @curl_title, $curl_line;
			}
			last;
		}
		# If we are between <title> and </title>, push it to the array
		elsif ( ($end_of_header == 1) && ($title_start_line != '-1' ) && ($title_start_line != $line_no ) ) {
			push @curl_title, $curl_line;
		}
		$line_no = $line_no + 1;
	}
	close($CURL_OUT);
	# Print out $is_text and $title's values
	print '$is_text = ' . "$is_text\n";
	print '@curl_title    = ' . @curl_title . "\n";
	print '$end_of_header = ' . "$end_of_header\n";
	# If we found the header, print out what line it starts on
	if ( $title_start_line != '-1' or $title_end_line != 1 ) {
		print '$title_start_line = ' . "$title_start_line  " . '$title_end_line = ' . $title_end_line . "\n";
	}
	else {
		print "No title found, searched $line_no lines\n";
	}

	if ($is_text and !defined $new_location) {
		# Handle a multi line url
		my $title_length = @curl_title;
		print "Lines in title: $title_length\n";
		if ($title_length == 1) {
			$title = $curl_title[0];
		}
		else {
			$title = join q( ), @curl_title;
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
	}
	return $title, $new_location, $is_text, $is_cloudflare, $has_cookie, $is_404;

}

sub find_url {
	my ($url, $new_location_text);
	my $max_title_length  = 120;
	my $error_line        =   0;

	my $url_finder = URI::Find->new(
		sub {
			my ( $uri, $orig_uri ) = @_;
			$url = $orig_uri;
		}
	);

	my $num_found = $url_finder->find( \$body );

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

		my($url_title, $url_new_location, $url_is_text, $url_is_cloudflare, $url_has_cookie, $url_is_404) = get_url($url);
		print "New location: $url_new_location\n";
		if ( defined $url_new_location ) {
			my $temp_var;
			($url_title, $temp_var, $url_is_text, $url_is_cloudflare, $url_has_cookie, $url_is_404) = get_url($url_new_location);
		}

		my $cloudflare_text = q();
		if ( $url_is_cloudflare == 1 ) {
			$cloudflare_text = ' **CLOUDFLARE**';
		}
		my $cookie_text = q();
		if ( $url_has_cookie >= 1 ) {
			$cookie_text = q( ) . q(@);
		}
		if ($url_is_404) {
			print "# $error_line # " . $cookie_text . $cloudflare_text . "$url\n";
			exit;
		}
		if ($url_is_text) {
			my $short_title = substr $url_title, 0, $max_title_length;
			if ( $url_title ne $short_title and $url !~ m{twitter[.]com/.+/status} ) {
				$url_title = $short_title . ' ...';
			}
			if ( !$url_title ) {
				print "No title found right before print\n";
				exit;
			}

			if ( $url_new_location ne q(%) ) {
				$new_location_text = " >> $url_new_location";
				chomp $new_location_text;
			}
			else {
				$new_location_text = q();
			}

			print "%[ $url_title ]" . $new_location_text . $cloudflare_text . $cookie_text . "\n";
		}
		else {
			exit;
		}
	}
}
# MAIN
# .bots reporting functionality
if ( $body =~ /[.]bots.*/xms ) {
	print "%$username reporting in! [perl] $repo_url v$VERSION\n";
}
#START
#END
# Sed functionality. Only called if the bot's username is set and it can know what history file
# to use.
elsif ( $body =~ m{^s/.+/} and $username ne q() ) {
	sed_replace;
}
else {
	find_url;
}
