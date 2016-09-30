#!/usr/bin/env perl
# said perlbot script
use strict;
use warnings;
use HTML::Entities 'decode_entities';
use IPC::Open3 'open3';

use feature 'unicode_strings';
use utf8;
use English;
use Encode 'decode_utf8';
use Time::Seconds;
use URL::Search 'extract_urls';

binmode STDOUT, ':encoding(UTF-8)' or print "Failed to set binmode on STDOUT, Error $ERRNO\n";
our $VERSION = 0.4;
my $repo_url = 'https://gitlab.com/samcv/perlbot';
my ( $who_said, $body, $username ) = @ARGV;

my ( $history_file, $tell_file );
my $history_file_length = 20;

my $help_text = 'Supports s/before/after (sed), !tell, and responds to .bots with bot info and '
	. 'repo url. Also posts the page title of any website pasted in channel';

my $tell_help_text    = 'Usage: !tell nick \"message to tell them\"';
my $tell_in_help_text = 'Usage: !tell in 100d/h/m/s nickname \"message to tell them\"';


my $said_time_called = time;

if ( ( !defined $body ) or ( !defined $who_said ) ) {
	print "Did not receive any input\n";
	print "Usage: said.pl nickname \"text\" botname\n";
	exit 1;
}
elsif ( defined $username ) {
	$history_file        = $username . '_history.txt';
	$tell_file           = $username . '_tell.txt';
	$history_file_length = 20;
	utf8::decode($username);

	# Add line to history file
	open my $history_fh, '>>', "$history_file"
		or print "Could not open history file, Error $ERRNO\n";
	binmode( $history_fh, ":encoding(UTF-8)" )
		or print 'Failed to set binmode on $history_fh, Error' . "$ERRNO\n";

	# Don't set binmode on $history_fh or it will break
	print $history_fh "<$who_said> $body\n"
		or print "Failed to append to $history_file, Error $ERRNO\n";
	close $history_fh or print "Could not close $history_file, Error $ERRNO\n";
}
utf8::decode($who_said);
utf8::decode($body);

sub convert_from_secs {
	my ($secs_to_convert) = @_;
	use integer;
	my ( $secs, $mins, $hours, $days, $years );

	if ( $secs_to_convert >= ONE_YEAR ) {
		$years           = $secs_to_convert / ONE_YEAR;
		$secs_to_convert = $secs_to_convert - $years * ONE_YEAR;
	}
	if ( $secs_to_convert >= ONE_DAY ) {
		$days            = $secs_to_convert / ONE_DAY;
		$secs_to_convert = $secs_to_convert - $days * ONE_DAY;
	}
	if ( $secs_to_convert >= ONE_HOUR ) {
		$hours           = $secs_to_convert / ONE_HOUR;
		$secs_to_convert = $secs_to_convert - $hours * ONE_HOUR;
	}
	if ( $secs_to_convert >= ONE_MINUTE ) {
		$mins            = $secs_to_convert / ONE_MINUTE;
		$secs_to_convert = $secs_to_convert - $mins * ONE_MINUTE;
	}
	$secs = $secs_to_convert;
	return $secs, $mins, $hours, $days, $years;
}

sub tell_nick {
	my ($tell_nick_who) = @_;
	my $tell_return;
	open my $tell_fh, '<', "$tell_file" or print "Could not open $tell_file, Error $ERRNO\n";
	binmode( $tell_fh, ':encoding(UTF-8)' )
		or print 'Failed to set binmode on $tell_fh, Error' . "$ERRNO\n";
	my @tell_lines = <$tell_fh>;
	close $tell_fh or print "Could not close $tell_file, Error $ERRNO\n";
	open $tell_fh, '>', "$tell_file" or print "Could not open $tell_file, Error $ERRNO\n";
	binmode( $tell_fh, ':encoding(UTF-8)' )
		or print 'Failed to set binmode on $tell_fh, Error' . "$ERRNO\n";
	my $has_been_said = 0;

	foreach my $tell_line (@tell_lines) {
		chomp $tell_line;
		my $time_var = $tell_line;
		$time_var =~ s/^\d+ (\d+) <.+>.*/$1/;
		if (    $tell_line =~ m{^\d+ \d+ <.+> >$tell_nick_who<}
			and ( !$has_been_said )
			and $time_var < $said_time_called )
		{
			chomp $tell_line;
			my $tell_nick_time_tell = $tell_line;
			$tell_nick_time_tell =~ s/^(\d+) .*/$1/;
			$tell_line =~ s{^\d+ \d+ }{};
			my $tell_time_diff = $said_time_called - $tell_nick_time_tell;
			print "Tell nick time diff: $tell_time_diff\n";
			my ( $tell_secs, $tell_mins, $tell_hours, $tell_days, $tell_years )
				= convert_from_secs($tell_time_diff);
			if ( defined $tell_years ) {
				$tell_return
					= "$tell_line [$tell_years"
					. "y $tell_days"
					. "d $tell_hours"
					. "h $tell_mins"
					. "m $tell_secs"
					. 's ago]';
			}
			elsif ( defined $tell_days ) {
				$tell_return
					= "$tell_line [$tell_days"
					. "d $tell_hours"
					. "h $tell_mins"
					. "m $tell_secs"
					. 's ago]';
			}
			elsif ( defined $tell_hours ) {
				$tell_return
					= "$tell_line [$tell_hours" . "h $tell_mins" . "m $tell_secs" . 's ago]';
			}
			elsif ( defined $tell_mins ) {
				$tell_return = "$tell_line [$tell_mins" . "m  $tell_secs" . 's ago]';
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
	close $tell_fh or print 'Could not close $tell_fh' . ", Error $ERRNO\n";
	if ( defined $tell_return ) {
		return $tell_return;
	}
	else {
		return;
	}
}

sub tell_nick_command {
	my ( $tell_nick_body, $tell_nick_who ) = @_;
	chomp $tell_nick_body;
	my $tell_remind_time = 0;

	my $tell_who         = $tell_nick_body;
	my $tell_text        = $tell_nick_body;
	my $tell_remind_when = $tell_nick_body;
	if ( $tell_nick_body =~ /^!tell in / or $tell_nick_body =~ /^!tell help/ ) {
		$tell_remind_when =~ s/!tell in (\S+) .*/$1/;
		$tell_text =~ s/!tell in \S+ \S+ (.*)/$1/;
		$tell_who =~ s/!tell in \S+ (\S+) .*/$1/;
		if ( $tell_remind_when =~ s/^(\d+)m$/$1/ ) {
			$tell_remind_time = $tell_remind_when * ONE_MINUTE + $said_time_called;
		}
		elsif ( $tell_remind_when =~ s/^(\d+)s$/$1/ ) {
			$tell_remind_time = $tell_remind_when + $said_time_called;
		}
		elsif ( $tell_remind_when =~ s/^(\d+)d$/$1/ ) {
			$tell_remind_time = $tell_remind_when * ONE_DAY + $said_time_called;
		}
		elsif ( $tell_remind_when =~ s/^(\d+)h$/$1/ ) {
			$tell_remind_time = $tell_remind_when * ONE_HOUR + $said_time_called;
		}

	}
	else {
		$tell_who =~ s/!tell (\S+) .*/$1/;
		$tell_text =~ s/!tell \S+ (.*)/$1/;
	}
	print "tell_nick_time_called: $said_time_called tell_remind_time: $tell_remind_time "
		. "tell_who: $tell_who tell_text: $tell_text\n";
	open my $tell_fh, '>>', "$tell_file" or print "Could not open $tell_file, Error $ERRNO\n";
	binmode( $tell_fh, ":encoding(UTF-8)" )
		or print 'Failed to set binmode on $tell_fh, Error' . "$ERRNO\n";
	print $tell_fh "$said_time_called $tell_remind_time <$tell_nick_who> >$tell_who< $tell_text\n"
		or print "Failed to append to $tell_file, Error $ERRNO\n";

	close $tell_fh or print "Could not close $tell_file, Error $ERRNO\n";
	return;
}

sub sed_replace {
	my ($sed_called_text) = @_;
	my $before = $sed_called_text;
	$before =~ s{^s/(.+?)/.*}{$1};
	my $after = $sed_called_text;
	$after =~ s{^s/.+?/(.*)}{$1};
	my $case_sensitivity = 0;

	# Remove trailing slash
	if ( $after =~ m{/(\S)$} ) {
		if ( $1 eq 'i' ) { $case_sensitivity = 1; }
		$after =~ s{/\S$}{};
	}
	$after =~ s{/$}{};
	print "first: $before\tsecond: $after\n";
	my $replaced_who;
	my $replaced_said;
	print "Trying to open $history_file\n";
	open my $history_fh, '<', "$history_file" or print "Could not open $history_file for read\n";
	binmode( $history_fh, ":encoding(UTF-8)" )
		or print 'Failed to set binmode on $history_fh, Error' . "$ERRNO\n";

	while ( defined( my $history_line = <$history_fh> ) ) {
		chomp $history_line;
		my $history_who = $history_line;
		$history_who =~ s{^<(.+?)>.*}{$1};
		my $history_said = $history_line;
		$history_said =~ s{^<.+?> }{};
		if ( $history_said =~ m{$before}i and $history_said !~ m{^s/} ) {
			print "Found match\n";
			my $temp_replaced_said = $history_said;

			# Allow use of [abc] to match either a,b or c
			if ( $before =~ m{^\[.*\]$} ) {
				my $before_2 = $before;
				$before_2 =~ s{^\[(.*)\]$}{$1};
				$temp_replaced_said =~ s{[$before_2]}{$after}g;
				if ( $history_said ne $temp_replaced_said ) {
					$replaced_said = $temp_replaced_said;
					$replaced_who  = $history_who;
					print "set1\n";
				}
			}
			else {
				if ( $case_sensitivity == 0 ) {
					$temp_replaced_said =~ s{\Q$before\E}{$after}g;
					if ( $history_said ne $temp_replaced_said ) {
						$replaced_said = $temp_replaced_said;
						$replaced_who  = $history_who;
						print "set2\n";
					}
				}
				elsif ( $case_sensitivity == 1 ) {
					$temp_replaced_said =~ s{\Q$before\E}{$after}ig;
					if ( $history_said ne $temp_replaced_said ) {
						$replaced_said = $temp_replaced_said;
						$replaced_who  = $history_who;
						print "set3\n";
					}
				}
			}
		}
	}
	close $history_fh or print "Could not close $history_file, Error: $ERRNO\n";
	if ( defined $replaced_said && defined $replaced_who ) {
		print "replaced_said: $replaced_said replaced_who: $replaced_who\n";
		open my $history_fh, '>>', "$history_file"
			or print "Could not open $history_file for write\n";
		binmode( $history_fh, ":encoding(UTF-8)" )
			or print 'Failed to set binmode on $history_fh, Error' . "$ERRNO\n";
		print $history_fh '<' . $replaced_who . '> ' . $replaced_said . "\n";
		close $history_fh or print "Could not close $history_file, Error: $ERRNO\n";
		return $replaced_who, $replaced_said;
	}
}

sub get_url_title {
	my ($sub_url) = @_;
	my @header_array;
	print "Curl Location: \"$sub_url\"\n";
	my ( $is_text, $end_of_header, $is_404, $has_cookie, $is_cloudflare ) = (0) x 5;
	my ( $title, $title_start_line, $title_between_line, $title_end_line, $new_location );
	my @curl_title;
	my $line_no          = 1;
	my $curl_retry_times = 1;
	my $user_agent
		= 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/53.0.2785.116 Safari/537.36';
	my $curl_max_time = 5;
	my @curl_args     = (
		'--compressed', '-s',              '-A',         $user_agent,
		'--retry',      $curl_retry_times, '--max-time', $curl_max_time,
		'--no-buffer',  '-i',              '--url',      $sub_url
	);

	# REGEX
	my $title_text_regex  = '\s*(.*\S+)\s*';
	my $title_start_regex = '.*<title.*?>';
	my $title_end_regex   = '</title>.*';
	my @curl_doc;
	my $temp_title;
	open3( undef, my $CURL_OUT, undef, 'curl', @curl_args )
		or print "Could not open curl pipe, Error $ERRNO\n";
	binmode( $CURL_OUT, ':encoding(UTF-8)' )
		or print 'Failed to set binmode on $CURL_OUT, Error ' . "$ERRNO\n";

	while ( defined( my $curl_line = <$CURL_OUT> ) ) {
		chomp $curl_line;

		# Remove starting and ending whitespace
		$curl_line =~ s/^\s*(.*)\s*$/$1/;

		# Processing done only within the header
		if ( $end_of_header == 0 ) {
			push @header_array, $curl_line;

			# Detect end of header
			if ( $curl_line =~ /^\s*$/ ) {
				$end_of_header = 1;

				if ( $is_text == 0 ) {
					print "Stopping because it's not text\n";
					print join( "\n", @header_array );
					last;
				}
				if ( defined $new_location ) {
					print "New Location: \"$new_location\" STOPPING at end of header\n";
					last;
				}
			}

			# Detect content type
			elsif ( $curl_line =~ /^Content-Type:.*text/i ) {
				$is_text = 1;
			}
			elsif ( $curl_line =~ /^CF-RAY:/i ) {
				$is_cloudflare = 1;
			}
			elsif ( $curl_line =~ /^Set-Cookie.*/i ) {
				$has_cookie++;
			}
			elsif ( $curl_line =~ /^Location:\s*/i ) {
				$new_location = $curl_line;
				$new_location =~ s/^Location:\s*(\S*)\s*$/$1/i;
			}
		}

		# Processing done after the header
		else {
			push @curl_doc, $curl_line;

			# Find the <title> element
			if ( $curl_line =~ s{$title_start_regex}{}i ) {
				$title_start_line = $line_no;
			}

			# Find the </title> element
			if ( $curl_line =~ s{$title_end_regex}{}i ) {
				$title_end_line = $line_no;
			}

			# If we are between <title> and </title>
			if ( defined $title_start_line && !defined $title_end_line ) {
				$title_between_line = $line_no;
			}

			if ( $title_start_line or $title_end_line or $title_between_line == $line_no ) {
				$curl_line =~ s{$title_text_regex}{$1};
				if ( $curl_line !~ /^\s*$/ ) {
					push @curl_title, $curl_line;
					print "Line $line_no is \"$curl_line\"\n";
				}
				if ( defined $title_end_line ) {
					last;
				}
			}

			# If we reach the </head> or <body> then we know we have gone too far
			if ( $curl_line =~ m{</head>} or $curl_line =~ m{<body.*?>} ) {
				print "We reached the body or the head> element and couldn't find any page title\n";
				last;
			}
		}

		$line_no++;
	}
	close $CURL_OUT or print "Could not close curl pipe, Error $ERRNO\n";

	my $title_non_blank_lines = scalar @curl_title;

	# Print out $is_text and $title's values
	print "Ended on line $line_no"
		. '  Is Text: '
		. "$is_text  "
		. 'Non-Blank Lines in Title: '
		. $title_non_blank_lines
		. '  End of Header: '
		. "$end_of_header\n";
	my $title_length = '?';
	if ( defined $title_start_line and defined $title_end_line ) {
		$title_length = $title_end_line - $title_start_line;
	}

	# If we found the header, print out what line it starts on
	if ( defined $title_start_line or defined $title_end_line ) {
		print 'Title Start Line: '
			. "$title_start_line  "
			. 'Title End Line = '
			. $title_end_line
			. " Lines from title start to end: $title_length\n";
	}
	elsif ( !defined $new_location ) {
		print "No title found, searched $line_no lines\n";
	}

	if ( $is_text and $curl_title[0] and ( !defined $new_location ) ) {

		# Flatten the title array, putting two spaces between lines
		$title = join q(  ), @curl_title;

		# Replace carriage returns with two spaces
		$title =~ s/\r/  /g;

		# Decode html entities such as &nbsp
		$title = decode_entities($title);
		print "Title is: \"$title\"\n";

		#return $title, $new_location, $is_text, $is_cloudflare, $has_cookie, $is_404;

	}
	return $title, $new_location, $is_text, $is_cloudflare, $has_cookie, $is_404;
}

sub find_url {
	my ($find_url_caller_text) = @_;
	my ( $find_url_url, $new_location_text );
	my $max_title_length = 120;
	my $error_line       = 0;
	my @find_url_array   = extract_urls $find_url_caller_text;

	foreach my $single_url (@find_url_array) {

		# Make sure we don't include FTP
		if ( $single_url !~ m{^ftp://} ) {
			$find_url_url = $single_url;
			print "Found $find_url_url as the first url\n";
			last;
		}
	}

	if ( defined $find_url_url ) {

		if ( $find_url_url =~ m/;/ ) {
			print "URL has comma(s) in it!\n";
			$find_url_url =~ s/;/%3B/xmsg;
			return 0;
		}
		if ( $find_url_url =~ m/\$/ ) {
			print "\$ sign found\n";
			return 0;
		}
		my $url_new_location;

		# ONE
		my ($url_title,         $url_new_location_1, $url_is_text,
			$url_is_cloudflare, $url_has_cookie,     $url_is_404
		) = get_url_title($find_url_url);
		my $redirects = 0;
		my ( $url_new_location_2, $url_new_location_3 );
		if ( defined $url_new_location_1 ) {
			(   $url_title,         $url_new_location_2, $url_is_text,
				$url_is_cloudflare, $url_has_cookie,     $url_is_404
			) = ();

			# TWO
			(   $url_title,         $url_new_location_2, $url_is_text,
				$url_is_cloudflare, $url_has_cookie,     $url_is_404
			) = get_url_title($url_new_location_1);

			if ( defined $url_new_location_2 ) {
				(   $url_title,         $url_new_location_3, $url_is_text,
					$url_is_cloudflare, $url_has_cookie,     $url_is_404
				) = ();

				# THREE
				(   $url_title,         $url_new_location_3, $url_is_text,
					$url_is_cloudflare, $url_has_cookie,     $url_is_404
				) = get_url_title($url_new_location_2);
			}

		}
		if ( defined $url_new_location_3 ) {
			print "Too many redirects!!! There are at least three\n";
		}
		elsif ( defined $url_new_location_2 ) {
			print "Found url new location 2\n";
			$url_new_location = $url_new_location_2;
		}
		elsif ( defined $url_new_location_1 ) {
			print "Found url new location 1\n";
			$url_new_location = $url_new_location_1;
		}

		if ( $url_is_text && defined $url_title ) {
			my $short_title = substr $url_title, 0, $max_title_length;
			if ( $url_title ne $short_title and $find_url_url !~ m{twitter[.]com/.+/status} ) {
				$url_title = $short_title . ' ...';
			}
			if ( !$url_title ) {
				print "find_url return, No title found right before print\n";
				return 0;
			}
			return ( 1, $find_url_url, $url_is_text, $url_title, $url_new_location,
				$url_is_cloudflare, $url_has_cookie, $url_is_404 );
		}
		else {
			print "find_url return, it's not text\n";
			return 0;
		}
	}
	else {
		return 0;
	}
}

sub url_format_text {
	my ( $format_success, $format_url, $format_is_text, $format_title, $format_new_location,
		$format_cloudflare, $format_cookie, $format_404 )
		= @_;
	my $cloudflare_text  = q();
	my $max_title_length = 120;
	if ( $format_cloudflare == 1 ) {
		$cloudflare_text = ' **CLOUDFLARE**';
	}
	my $new_location_text;
	my $cookie_text;
	if ( $format_cookie >= 1 ) {
		$cookie_text = q( ) . q([ 🍪 ]);
	}
	else {
		$cookie_text = q();
	}
	if ($format_404) {
		print "find_url return, 404 error\n";
		return 0;
	}
	if ($format_is_text) {
		my $short_title = substr $format_title, 0, $max_title_length;
		if ( $format_title ne $short_title and $format_url !~ m{twitter[.]com/.+/status} ) {
			$format_title = $short_title . ' ...';
		}
		if ( !$format_title ) {
			print "find_url return, No title found right before print\n";
			return 0;
		}

		if ( defined $format_new_location ) {
			$new_location_text = " >> $format_new_location";
			chomp $new_location_text;
		}
		else {
			$new_location_text = q();
		}
		return 1, "[ $format_title ]" . $new_location_text . $cloudflare_text . $cookie_text;
	}
	else {
		return 0;
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
	my ( $sed_who, $sed_text ) = sed_replace($body);
	my $sed_short_text = substr $sed_text, 0, '250';
	if ( $sed_text ne $sed_short_text ) {
		$sed_text = $sed_short_text . ' ...';
	}
	if ( defined $sed_who and defined $sed_text ) {
		print "sed_who: $sed_who sed_text: $sed_text\n";
		print "%<$sed_who> $sed_text\n";
	}
}

elsif ( $body =~ /^!help/i ) {
	print "%$help_text\n";
}

# Find and get URL's page title
# Don't get the page header if there's a ## in front of it
if ( $body !~ m{\#\#\s*http.?://} ) {
	my ($main_find_url_success, $main_find_url_url,     $main_url_is_text,
		$main_url_title,        $main_url_new_location, $main_url_is_cloudflare,
		$main_url_has_cookie,   $main_url_is_404
	) = find_url($body);

	#my ( $url_success, $main_url_title ) = find_url($body);
	if ( $main_find_url_success != 0 and defined $main_url_title ) {
		my $main_url_formatted_text = url_format_text(
			$main_find_url_success, $main_find_url_url,     $main_url_is_text,
			$main_url_title,        $main_url_new_location, $main_url_is_cloudflare,
			$main_url_has_cookie,   $main_url_is_404
		);
		if ( defined $main_url_formatted_text ) {
			print "%$main_url_formatted_text\n";
		}
	}
	elsif ( !defined $main_url_title and $main_find_url_success == 1 ) {
		print "No url title found right before channel message\n";
	}
}

if ( defined $username ) {
	if ( $username ne q() ) {
		if ( $body =~ /^!tell/ ) {
			if ( $body !~ /^!tell \S+ \S+/ or $body =~ /^!tell help/ ) {
				print "%$tell_help_text\n";
			}
			elsif ( $body =~ /^!tell in/ and $body !~ /!tell in \d+[smhd] / ) {
				print "%$tell_in_help_text\n";
			}
			else {
				print "Calling tell_nick_command\n";
				tell_nick_command( $body, $who_said );
			}
		}
		if ( -f $tell_file ) {
			print "Calling tell_nick\n";
			my ($tell_to_say) = tell_nick($who_said);
			if ( defined $tell_to_say ) {
				print "Tell to say line next\n";
				print "%$tell_to_say\n";
			}
		}

		# Trunicate history file only if the bot's username is set.
		`tail -n $history_file_length ./$history_file | sponge ./$history_file`
			and print "Problem with tail ./$history_file | sponge ./$history_file, Error $ERRNO\n";
	}
}

exit;
