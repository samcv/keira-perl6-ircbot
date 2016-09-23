#!/usr/bin/env perl
# said perlbot script
use strict;
use warnings;
use LWP::Simple;
use URI::Find;
use HTML::Entities;
use IPC::Open3;
use feature 'unicode_strings';
use utf8;

our $VERSION = 0.3;
my $repo_url = 'https://gitlab.com/samcv/perlbot';

my($who_said, $body, $username) = @ARGV;

my $history_file;
my $history_file_length = '20';

my $help_text = 'Supports s/before/after (sed), !tell, and responds to .bots with bot info and ' .
                'repo url. Also posts the page title of any website pasted in channel';

my $tell_help_text    = "Usage: !tell nick \"message to tell them\"";
my $tell_in_help_text = "Usage: !tell in 100d/h/m/s nickname \"message to tell them\"";

my $SECS_PER_MIN  = 60;
my $SECS_PER_HOUR = 60  * $SECS_PER_MIN;
my $SECS_PER_DAY  = 24  * $SECS_PER_HOUR;
my $SECS_PER_YEAR = 365 * $SECS_PER_DAY;

if ( !defined $body or !defined $who_said ) {
	print "Did not receive any input\n";
	print "Usage: said.pl nickname \"text\" botname\n";
	exit 1;
}
elsif ( defined $username ) {
	$history_file  = $username . '_history.txt';
	$history_file_length = '20';
}

sub convert_from_secs {
	use integer;
	my ($secs_to_convert) = @_;
	my ($secs, $mins, $hours, $days, $years);
	
	if ( $secs_to_convert >= $SECS_PER_YEAR ) {
		$years = $secs_to_convert / $SECS_PER_YEAR;
		$secs_to_convert = $secs_to_convert - $years * $SECS_PER_YEAR;
	}
	if ( $secs_to_convert >= $SECS_PER_DAY ) {
		$days  = $secs_to_convert / $SECS_PER_DAY;
		$secs_to_convert = $secs_to_convert - $days * $SECS_PER_DAY;
	}
	if ( $secs_to_convert >= $SECS_PER_HOUR ) {
		$hours = $secs_to_convert / $SECS_PER_HOUR;
		$secs_to_convert = $secs_to_convert - $hours * $SECS_PER_HOUR;
	}
	if ( $secs_to_convert >= $SECS_PER_MIN ) {
		$mins = $secs_to_convert / $SECS_PER_MIN;
		$secs_to_convert = $secs_to_convert - $mins * $SECS_PER_MIN;
	}
	$secs = $secs_to_convert;
	return $secs, $mins, $hours, $days, $years;
}

sub tell_nick {
	my ($tell_nick_body, $tell_nick_who) = @_;
	chomp $tell_nick_body;
	# Make sure this sub uses integer division so we get proper results
	use integer;

	my $tell_return;

	my $tell_file = $username . '_tell.txt';
	my $tell_time_called = time;
	my $tell_remind_time = 0;

	if ($tell_nick_body =~ /^!tell/ and ( $body =~ /^!tell \S+ \S+/ or $body !~ /^!tell help/ ) ) {
		my $tell_who = $tell_nick_body;
		my $tell_text = $tell_nick_body;
		my $tell_remind_when = $tell_nick_body;
		if ( $tell_nick_body =~ /^!tell in / or $tell_nick_body =~ /^!tell help/ ) {
			$tell_remind_when =~ s/!tell in (\S+) .*/$1/;
			$tell_text        =~ s/!tell in \S+ \S+ (.*)/$1/;
			$tell_who         =~ s/!tell in \S+ (\S+) .*/$1/;
			if ( $tell_remind_when =~ s/^([0-9]+)m$/$1/ ) {
				$tell_remind_time = $tell_remind_when * $SECS_PER_MIN + $tell_time_called;
			}
			elsif ( $tell_remind_when =~ s/^([0-9]+)s$/$1/ ) {
				$tell_remind_time = $tell_remind_when + $tell_time_called;
			}
			elsif ( $tell_remind_when =~ s/^([0-9]+)d$/$1/ ) {
				$tell_remind_time = $tell_remind_when * $SECS_PER_DAY + $tell_time_called;
			}
			elsif ( $tell_remind_when =~ s/^([0-9]+)h$/$1/ ) {
				$tell_remind_time = $tell_remind_when * $SECS_PER_HOUR + $tell_time_called;
			}

		}
		else {
			$tell_who =~ s/!tell (\S+) .*/$1/;
			$tell_text =~ s/!tell \S+ (.*)/$1/;
		}
		print "tell_nick_time_called: $tell_time_called tell_remind_time: $tell_remind_time " .
		      "tell_who: $tell_who tell_text: $tell_text\n";
		open my $tell_fh, '>>', "$tell_file" or print "Could not open $tell_file, Error $?\n";
		print $tell_fh "$tell_time_called $tell_remind_time <$tell_nick_who> >$tell_who< $tell_text\n"
			or print "Failed to append to $tell_file, Error $?\n";
		close $tell_fh or print "Could not close $tell_file, Error $?\n";
	}
	open my $tell_fh, '<', "$tell_file" or print "Could not open $tell_file, Error $?\n";
	my @tell_lines = <$tell_fh>;
	close $tell_fh;
	open $tell_fh, '>', "$tell_file" or print "Could not open $tell_file, Error $?\n";
	my $has_been_said = 0;
	foreach my $tell_line (@tell_lines) {
		chomp $tell_line;
		my $time_var = $tell_line;
		$time_var =~ s/^[0-9]+ ([0-9]+) <.+>.*/$1/;
		if ( $tell_line =~ /^[0-9]+ [0-9]+ <.+> >$tell_nick_who</ and !$has_been_said and $time_var < $tell_time_called ) {
			chomp $tell_line;
			my $tell_nick_time_tell = $tell_line;
			$tell_nick_time_tell =~ s/^([0-9]+) .*/$1/;
			$tell_line =~ s{^[0-9]+ [0-9]+ }{};
			my $tell_time_diff = $tell_time_called - $tell_nick_time_tell;
			print "Tell nick time diff: $tell_time_diff\n";
			my ($tell_secs, $tell_mins, $tell_hours, $tell_days, $tell_years) = convert_from_secs($tell_time_diff);
			if ( defined $tell_years ) {
				$tell_return = "$tell_line [$tell_years" . "y $tell_days" . "d $tell_hours" . "h $tell_mins" . "m " . $tell_secs . "s ago]";
			}
			elsif ( defined $tell_days ) {
				$tell_return =  "$tell_line [$tell_days" . "d $tell_hours" . "h $tell_mins" . "m " . $tell_secs . "s ago]";
			}
			elsif ( defined $tell_hours ) {
				$tell_return =  "$tell_line [$tell_hours" . "h $tell_mins" . "m " . $tell_secs . "s ago]";
			}
			elsif ( defined $tell_mins ) {
				$tell_return = "$tell_line [$tell_mins" . "m " . $tell_secs . "s ago]";
			}
			else {
				$tell_return = "$tell_line [$tell_time_diff" . "s ago]";
			}
			$has_been_said = 1;
		}
		else {
			print $tell_fh "$tell_line\n";
		}
	}
	close $tell_fh;
	if ( defined $tell_return ) {
		return $tell_return;
	}
	else {
		return;
	}
}

sub sed_replace {
	my ($sed_called_text) = @_;
	my $first = $sed_called_text;
	$first =~ s{^s/(.+?)/.*}{$1};
	my $second = $sed_called_text;
	$second =~ s{^s/.+?/(.*)}{$1};
	print "first: $first\tsecond: $second\n";
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
		$history_said =~ s{<.+> }{};
		if ( $history_said =~ m{$first}i and $history_said !~ m{^s/} ) {
			print "Found match\n";
			$replaced_said = $history_said;
			$replaced_said =~ s{\Q$first\E}{$second}ig;
			$replaced_who = $history_who;
			print "replaced_said: $replaced_said\n";
		}
	}
	close $history_fh;
	if ( defined $replaced_said ) {
		return $replaced_who, $replaced_said;
	}
}

sub get_url {
	my ($sub_url) = @_;
	print "get_url, url is $sub_url\n";
	my ($is_text, $end_of_header, $is_404, $has_cookie, $is_cloudflare) = ('0')  x '5';
	my ($title, $title_start_line, $title_end_line)                     = ('-1') x '3';
	my $line_no       =  1;

	my $new_location;
	my @curl_title;
	my $user_agent    = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/53.0.2785.116 Safari/537.36';
	my $curl_max_time =  '5';
	push my @curl_args, '--compressed', '-A', $user_agent, '--max-time', $curl_max_time, '--no-buffer', '-i', '--url', $sub_url;

	open3 ( undef, my $CURL_OUT, undef, "curl", @curl_args);

	while  ( defined (my $curl_line = <$CURL_OUT>) ) {
		# Detect end of header
		if ( $curl_line =~ /^\s*$/ and $end_of_header == 0 ) {
			$end_of_header = 1;
			print "end of header detected\n";
			if ($is_text == 0 ) {
				print "Stopping because it's not text\n";
				last;
			}
			if (defined $new_location) {
				print "Stopping at end of header because there's a new location to go to\n";
			}
		}
		# Detect content type
		if ( $curl_line =~ /^\s*Content-Type:\s*text/i and $end_of_header == 0 ) {
			print "Curl header says it's text\n";
			$is_text = 1;
		}
		elsif ( $curl_line =~ /^\s*CF-RAY:/i ) {
			$is_cloudflare = 1;
			print "Cloudflare = 1\n";
		}
		elsif ( $curl_line =~ /^\s*Set-Cookie.*/i ) {
			$has_cookie++;
		}
		elsif ( $curl_line =~ /^\s*Location:\s*/i ) {
			$new_location = $curl_line;
			$new_location =~ s/^\s*Location:\s*//i;
			$new_location =~ s/^\s+|\s+$//g;
			print "sub get_url New Location: $new_location\n";
		}

		# Find the Title
		if ( $end_of_header == 1 and $curl_line =~ s/.*<title>\s?//i ) {
			$title_start_line = $line_no;
			# If the line is empty don't push it to the array
			if ( $curl_line =~ /^\s*$/) {
			}
			else {
				# Remove trailing and ending whitespace
				$curl_line =~ s/^\s*(.+)\s*$/$1/;
				push @curl_title, $curl_line;
			}
		}

		if ( $end_of_header == 1 and $curl_line =~ s/\s*<\/title>.*//i ) {
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
				# Remove trailing and ending whitespace
				$curl_line =~ s/^\s*(.+)\s*$/$1/;
				push @curl_title, $curl_line;
			}
			last;
		}
		# If we are between <title> and </title>, push it to the array
		elsif ( $end_of_header == 1 and $title_start_line != '-1' and $title_start_line != $line_no ) {
			# Remove trailing and ending whitespace
			$curl_line =~ s/^\s*(.+)\s*$/$1/;
			push @curl_title, $curl_line;
		}
		$line_no = $line_no + 1;
	}
	close $CURL_OUT;
	print "Ended on line $line_no\n";
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
			return;
		}

		# Replace newlines with two spaces
		#$title =~ s/\n/  /g;
		# Replace carriage returns with two spaces
		$title =~ s/\r/  /g;
		# Decode html entities such as &nbsp
		$title = decode_entities($title);
	}
	return $title, $new_location, $is_text, $is_cloudflare, $has_cookie, $is_404;

}

sub find_url {
	my ($find_url_caller_text) = @_;
	my ($find_url_url, $new_location_text);
	my $max_title_length  = 120;
	my $error_line        =   0;

	my $url_finder = URI::Find->new(
		sub {
			my ( $uri, $orig_uri ) = @_;
			$find_url_url = $orig_uri;
		}
	);

	my $num_found = $url_finder->find( \$find_url_caller_text );

	print "Numfound: $num_found\n";
	if ($num_found >= 1) {
		print "Number of URL's found $num_found \n";

		if ( $find_url_url eq '%' ) {
			print "Empty url found!\n";
			return;
		}
		if ( $find_url_url =~ m/;/ ) {
			print "URL has comma(s) in it!\n";
			$find_url_url =~ s/;/%3B/xmsg;
			return;
		}
		if ( $find_url_url =~ m/\$/ ) {
			print "\$ sign found\n";
			return;
		}

		my($url_title, $url_new_location, $url_is_text, $url_is_cloudflare, $url_has_cookie, $url_is_404) = get_url($find_url_url);
		print "sub find_url New Location: $url_new_location\n";
		if ( defined $url_new_location ) {
			my $temp_var;
			($url_title, $temp_var, $url_is_text, $url_is_cloudflare, $url_has_cookie, $url_is_404) = get_url($url_new_location);
			print "sub find_url Second New Location: $url_new_location\n";

		}
		my $cloudflare_text = q();
		if ( $url_is_cloudflare == 1 ) {
			$cloudflare_text = ' **CLOUDFLARE**';
		}
		my $cookie_text;
		if ( $url_has_cookie >= 1 ) {
			$cookie_text = q( ) . q(@);
		}
		if ($url_is_404) {
			print "find_url return, 404 error\n";
			return;
		}
		if ($url_is_text) {
			my $short_title = substr $url_title, 0, $max_title_length;
			if ( $url_title ne $short_title and $find_url_url !~ m{twitter[.]com/.+/status} ) {
				$url_title = $short_title . ' ...';
			}
			if ( !$url_title ) {
				print "find_url return, No title found right before print\n";
				return;
			}

			if (defined $url_new_location ) {
				$new_location_text = " >> $url_new_location";
				chomp $new_location_text;
			}
			else {
				$new_location_text = q();
			}

			return 1, $url_title, $new_location_text, $cloudflare_text, $cookie_text;
		}
		else {
			print "find_url return, it's not text\n";
			return;
		}
	}
}
# MAIN
# .bots reporting functionality
if ( $body =~ /[.]bots.*/ ) {
	print "%$username reporting in! [perl] $repo_url v$VERSION\n";
}
# Sed functionality. Only called if the bot's username is set and it can know what history file
# to use.
elsif ( $body =~ m{^s/.+/} and defined $username ) {
	my ($sed_who, $sed_text) = sed_replace($body);
	my $sed_short_text = substr $sed_text, 0, 250;
	if ( $sed_text ne $sed_short_text ) {
		$sed_text = $sed_short_text . ' ...';
	}
	if ( defined $sed_who and defined $sed_text) {
		print "%<$sed_who> $sed_text\n";
	}
}
elsif ( $body =~ /^!help/i ) {
	print "%$help_text\n";
}
else {
	my ($url_success, $main_url_title, $main_new_location_text, $main_cloudflare_text, $main_cookie_text) = find_url($body);
	if ($url_success and $main_url_title != -1 ) {
		print "%[ $main_url_title ]" . $main_new_location_text . $main_cloudflare_text . $main_cookie_text . "\n";
	}
	else {
		print "No url success\n";
	}
}
if ( defined $username ) {
	# Trunicate history file only if the bot's username is set.
	`tail -n $history_file_length ./$history_file | sponge ./$history_file`
	  and print "Problem with tail ./$history_file | sponge ./$history_file, Error $?\n";
	if ( $body =~ /^!tell/ and ( $body !~ /^!tell \S+ \S+/ or $body =~ /^!tell help/ ) ) {
		  print "%$tell_help_text\n";
	}
	elsif ( $body =~ /^!tell in/ and $body !~ /!tell in ([0-9]+)[smhd] / ) {
		print "%$tell_in_help_text\n";
	}
	my ($tell_to_say) = tell_nick($body, $who_said);
	if ( defined $tell_to_say ) {
		print "%$tell_to_say\n";
	}
}
