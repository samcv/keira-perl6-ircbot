#!/usr/bin/env perl
# said perlbot script
use strict;
use warnings;
use HTML::Entities 'decode_entities';
use IPC::Open3 'open3';
use Encode;
use Encode::Detect;
use feature 'unicode_strings';
use utf8;
use English;
use Time::Seconds;
use URL::Search 'extract_urls';

binmode STDOUT, ':encoding(UTF-8)' or print "Failed to set binmode on STDOUT, Error $ERRNO\n";
our $VERSION = 0.4;
my $repo_url = 'https://gitlab.com/samcv/perlbot';
my ( $who_said, $body, $bot_username ) = @ARGV;

my ( $history_file, $tell_file, $channel_event_file );
my $history_file_length = 20;

my $help_text = 'Supports s/before/after (sed), !tell, and responds to .bots with bot info and '
	. 'repo url. Also posts the page title of any website pasted in channel';
my $welcome_text
	= "Welcome to the channel $who_said. We're friendly here, read the topic and please be patient.";

my $tell_help_text    = 'Usage: !tell nick "message to tell them"';
my $tell_in_help_text = 'Usage: !tell in 100d/h/m/s nickname \"message to tell them\"';

print "Body before is $body\n";
my $said_time_called = time;

if ( ( !defined $body ) or ( !defined $who_said ) ) {
	print "Did not receive any input\n";
	print "Usage: said.pl nickname \"text\" botname\n";
	exit 1;
}
else {
	utf8::decode($who_said);
	utf8::decode($body);
}
if ( defined $bot_username and $bot_username ne q() ) {
	$history_file       = $bot_username . '_history.txt';
	$tell_file          = $bot_username . '_tell.txt';
	$channel_event_file = $bot_username . '_event.txt';

	$history_file_length = 20;
	utf8::decode($bot_username);


	# Add line to history file
	open my $history_fh, '>>', "$history_file"
		or print "Could not open history file, Error $ERRNO\n";
	binmode $history_fh, ':encoding(UTF-8)'
		or print 'Failed to set binmode on $history_fh, Error' . "$ERRNO\n";

	print {$history_fh} "<$who_said> $body\n"
		or print "Failed to append to $history_file, Error $ERRNO\n";
	close $history_fh or print "Could not close $history_file, Error $ERRNO\n";

}

sub seen_nick {
	my ( $seen_who_said, $seen_cmd ) = @_;
	my $nick = $seen_cmd;
	$nick =~ s/^!seen (\S+).*/$1/;
	my $event_file_exists = 0;
	my @event_after_array;
	my $is_in_file;
	my $return_string;

	open my $event_read_fh, '<', "$channel_event_file"
		or print "Could not open seen file, Error $ERRNO\n";
	binmode $event_read_fh, ':encoding(UTF-8)'
		or print 'Failed to set binmode on $event_read_fh, Error' . "$ERRNO\n";
	my @event_array = <$event_read_fh>;
	my ( $event_who_update, $event_spoke_update, $event_join_update, $event_part_update );

	foreach my $line (@event_array) {
		chomp $line;
		$line =~ m/^<(\S+?)> (\d+) (\d+) (\d+)/;
		my $event_who_file   = $1;
		my $event_spoke_file = $2;
		my $event_join_file  = $3;
		my $event_part_file  = $4;

		# If the nick matches we need to save the data
		if ( $nick =~ /^$event_who_file?.?/i ) {
			$is_in_file         = 1;
			$event_who_update   = $event_who_file;
			$event_spoke_update = $event_spoke_file;
			$event_join_update  = $event_join_file;
			$event_part_update  = $event_part_file;
		}
	}
	if ( $is_in_file == 1 ) {
		$return_string = $event_who_update;
		if ( $event_spoke_update != 0 ) {
			$return_string = $return_string . " Last spoke: " . format_time($event_spoke_update);
		}
		if ( $event_join_update != 0 ) {
			$return_string = $return_string . " Last joined: " . format_time($event_join_update);
		}
		if ( $event_part_update != 0 ) {
			$return_string
				= $return_string . " Last parted/quit: " . format_time($event_part_update);
		}
		print "%$return_string\n";
	}

}

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

sub format_time {
	my ($format_time_arg) = @_;
	my $format_time_now = time;
	my $tell_return;
	my $tell_time_diff = $format_time_now - $format_time_arg;

	my ( $tell_secs, $tell_mins, $tell_hours, $tell_days, $tell_years )
		= convert_from_secs($tell_time_diff);
	$tell_return = '[';
	if ( defined $tell_years ) {
		$tell_return = $tell_return . $tell_years . 'y ';
	}
	if ( defined $tell_days ) {
		$tell_return = $tell_return . $tell_days . 'd ';
	}
	if ( defined $tell_hours ) {
		$tell_return = $tell_return . $tell_hours . 'h ';
	}
	if ( defined $tell_mins ) {
		$tell_return = $tell_return . $tell_mins . 'm ';
	}
	if ( defined $tell_secs ) {
		$tell_return = $tell_return . $tell_secs . 's ';
	}
	$tell_return = $tell_return . 'ago]';
	return $tell_return;
}

sub tell_nick {
	my ($tell_nick_who) = @_;
	my $tell_return;
	open my $tell_fh, '<', "$tell_file" or print "Could not open $tell_file, Error $ERRNO\n";
	binmode $tell_fh, ':encoding(UTF-8)'
		or print 'Failed to set binmode on $tell_fh, Error' . "$ERRNO\n";
	my @tell_lines = <$tell_fh>;
	close $tell_fh or print "Could not close $tell_file, Error $ERRNO\n";
	open $tell_fh, '>', "$tell_file" or print "Could not open $tell_file, Error $ERRNO\n";
	binmode $tell_fh, ':encoding(UTF-8)'
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

			my $tell_formatted_time = format_time($tell_nick_time_tell);
			$tell_return   = "$tell_line " . $tell_formatted_time;
			$has_been_said = 1;
		}
		else {
			print {$tell_fh} "$tell_line\n";
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
	binmode $tell_fh, ':encoding(UTF-8)'
		or print 'Failed to set binmode on $tell_fh, Error' . "$ERRNO\n";
	print {$tell_fh}
		"$said_time_called $tell_remind_time <$tell_nick_who> >$tell_who< $tell_text\n"
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
	binmode $history_fh, ':encoding(UTF-8)'
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
		binmode( $history_fh, ':encoding(UTF-8)' )
			or print 'Failed to set binmode on $history_fh, Error' . "$ERRNO\n";
		print {$history_fh} '<' . $replaced_who . '> ' . $replaced_said . "\n";
		close $history_fh or print "Could not close $history_file, Error: $ERRNO\n";
		return $replaced_who, $replaced_said;
	}
}

sub get_url_title {
	my ($sub_url) = @_;
	print "Curl Location: \"$sub_url\"\n";
	my ( $is_text, $end_of_header, $is_404, $has_cookie, $is_cloudflare ) = (0) x 5;
	my ( $title_start_line, $title_between_line, $title_end_line ) = (0) x 3;
	my ( @curl_title, $new_location, $title );
	my $line_no          = 1;
	my $curl_retry_times = 1;
	my $user_agent
		= 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/53.0.2785.116 Safari/537.36';
	my $curl_max_time = 5;
	my @curl_args     = (
		'--compressed', '-s',              '-A',         $user_agent,
		'--retry',      $curl_retry_times, '--max-time', $curl_max_time,
		'--no-buffer',  '-i',              '--url',      $sub_url,
	);

	# REGEX
	my $title_text_regex  = '\s*(.*\S+)\s*';
	my $title_start_regex = '.*<title.*?>';
	my $title_end_regex   = '</title>.*';

	# Don't set BINMODE on curl's output because we will decode later on
	open3( undef, my $CURL_OUT, undef, 'curl', @curl_args )
		or print "Could not open curl pipe, Error $ERRNO\n";
	while ( defined( my $curl_line = <$CURL_OUT> ) ) {

		# Processing done only within the header
		if ( $end_of_header == 0 ) {

			# Detect end of header
			if ( $curl_line =~ /^\s*$/ ) {
				$end_of_header = 1;
				if ( $is_text == 0 || defined $new_location ) {
					print "Stopping because it's not text or a new location is defined\n";
					last;
				}
			}

			# Detect content type
			elsif ( $curl_line =~ /^Content-Type:.*text/i )       { $is_text       = 1 }
			elsif ( $curl_line =~ /^CF-RAY:/i )                   { $is_cloudflare = 1 }
			elsif ( $curl_line =~ /^Set-Cookie.*/i )              { $has_cookie++ }
			elsif ( $curl_line =~ s/^Location:\s*(\S*)\s*$/$1/i ) { $new_location  = $curl_line }
		}

		# Processing done after the header
		else {

			# Find the <title> element
			if ( $curl_line =~ s{$title_start_regex}{}i ) {
				$title_start_line = $line_no;
			}

			# Find the </title> element
			if ( $curl_line =~ s{$title_end_regex}{}i ) {
				$title_end_line = $line_no;
			}

			# If we are between <title> and </title>
			elsif ( $title_start_line != 0 && $title_end_line == 0 ) {
				$title_between_line = $line_no;
			}

			if ( $title_start_line or $title_end_line or $title_between_line == $line_no ) {
				$curl_line =~ s{$title_text_regex}{$1};
				if ( $curl_line !~ /^\s*$/ ) {
					push @curl_title, $curl_line;
					print "Line $line_no is \"$curl_line\"\n";
				}
			}

			# If we reach the </head>, <body> have reached the end of title
			if ( $curl_line =~ m{</head>} or $curl_line =~ m{<body.*?>} or $title_end_line != 0 ) {
				last;
			}
		}

		$line_no++;
	}
	close $CURL_OUT or print "Could not close curl pipe, Error $ERRNO\n";

	# Print out $is_text and $title's values
	print "Ended on line $line_no  "
		. 'Is Text: '
		. "$is_text  "
		. 'Non-Blank Lines in Title: '
		. scalar @curl_title . q(  )
		. 'End of Header: '
		. "$end_of_header\n";

	if ( $curl_title[0] and ( !defined $new_location ) ) {
		my $title_length = $title_end_line - $title_start_line;
		print 'Title Start Line: '
			. "$title_start_line  "
			. 'Title End Line = '
			. $title_end_line
			. " Lines from title start to end: $title_length\n";

		# Flatten the title array, putting two spaces between lines
		$title = join q(  ), @curl_title;

		# Detect the encoding of the title and decode it to UTF-8
		$title = decode( "Detect", $title );

		# Decode html entities such as &nbsp
		$title = decode_entities($title);

		# Replace carriage returns with two spaces
		$title =~ s/\r/  /g;

		print "Title is: \"$title\"\n";
	}
	my %object = (
		url           => $sub_url,
		title         => $title,
		new_location  => $new_location,
		is_text       => $is_text,
		is_cloudflare => $is_cloudflare,
		has_cookie    => $has_cookie,
		is_404        => $is_404,
	);
	return %object;
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
		elsif ( $find_url_url =~ m/\$/ ) {
			print "\$ sign found\n";
			return 0;
		}
		my $url_new_location;

		my %url_object = get_url_title($find_url_url);

		my $redirects = 0;
		while ( defined $url_object{new_location} and $redirects < 3 ) {
			$redirects++;
			if ( defined $url_object{new_location} ) {
				$url_new_location = $url_object{new_location};
				%url_object       = get_url_title($url_new_location);
			}
		}
		$url_object{new_location} = $url_new_location;

		if ( $url_object{is_text} && defined $url_object{title} ) {
			my $short_title = substr $url_object{title}, 0, $max_title_length;
			if (    $url_object{title} ne $short_title
				and $find_url_url !~ m{twitter[.]com/.+/status} )
			{
				$url_object{'title'} = $short_title . ' ...';
			}
			return ( 1, %url_object );
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
	my ( $format_success, %url_format_object ) = @_;

	my $cloudflare_text  = q();
	my $max_title_length = 120;
	if ( $url_format_object{is_cloudflare} == 1 ) {
		$cloudflare_text = ' **CLOUDFLARE**';
	}
	my $new_location_text;
	my $cookie_text;
	if ( $url_format_object{has_cookie} >= 1 ) {
		$cookie_text = q( ) . q([ 🍪 ]);
	}
	else {
		$cookie_text = q();
	}
	if ( $url_format_object{is_404} ) {
		print "find_url return, 404 error\n";
		return 0;
	}
	if ( $url_format_object{is_text} ) {
		my $short_title = substr $url_format_object{title}, 0, $max_title_length;
		if (    $url_format_object{title} ne $short_title
			and $url_format_object{url} !~ m{twitter[.]com/.+/status} )
		{
			$url_format_object{title} = $short_title . ' ...';
		}
		if ( !$url_format_object{title} ) {
			print "find_url return, No title found right before print\n";
			return 0;
		}

		if ( defined $url_format_object{new_location} ) {
			$new_location_text = " >> $url_format_object{new_location}";
			chomp $new_location_text;
		}
		else {
			$new_location_text = q();
		}
		return 1,
			  "[ $url_format_object{title} ]"
			. $new_location_text
			. $cloudflare_text
			. $cookie_text;
	}
	else {
		return 0;
	}
}

# MAIN
# .bots reporting functionality
if ( $body =~ /[.]bots.*/ ) {
	print "%$bot_username reporting in! [perl] $repo_url v$VERSION\n";
}

# Sed functionality. Only called if the bot's username is set and it can know what history file
# to use.
elsif ( $body =~ m{^s/.+/} and defined $bot_username ) {
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

# The bot will say Yes or No if you address it with its name and there's a question mark in the
# sentence.
elsif ( $body =~ /$bot_username/ and $body =~ /[?]/ ) {
	if ( $body =~ /[?]/ ) {
		my $coin       = int rand 2;
		my $coin_3     = int rand 3;
		my $thing_said = $body;
		$thing_said =~ s/^$bot_username\S?\s*//;
		$thing_said =~ s/[?]//g;
		if ( $body =~ /or/ ) {
			my $count_or;
			my $word = 'or';
			while ( $body =~ /\b$word\b/g ) {
				++$count_or;
			}
			print "There are $count_or words of or\n";
			if ( $count_or > 2 ) {
				print "%I don't support asking more than three things at once...yet\n";
			}
			elsif ( $count_or == 2 ) {
				if    ( $coin_3 == 0 ) { print "%The first one: $thing_said\n" }
				elsif ( $coin_3 == 1 ) { print "%The second one: $thing_said\n" }
				elsif ( $coin_3 == 2 ) { print "%The third one: $thing_said\n" }
			}
			else {
				if   ($coin) { print "%The first one: $thing_said\n" }
				else         { print "%The second one: $thing_said\n" }
			}
		}
		else {
			if   ($coin) { print "%Yes: $thing_said\n" }
			else         { print "%No: $thing_said\n" }
		}
	}

}

elsif ( $body =~ /^!help/i ) {
	print "%$help_text\n";
}

# Find and get URL's page title
# Don't get the page header if there's a ## in front of it
if ( $body !~ m{\#\#\s*http.?://} ) {
	my ( $main_find_url_success, %main_url_object ) = find_url($body);

	if ( $main_find_url_success != 0 and defined $main_url_object{title} ) {
		my $main_url_formatted_text = url_format_text( $main_find_url_success, %main_url_object );
		if ( defined $main_url_formatted_text ) {
			print "%$main_url_formatted_text\n";
		}
	}
	elsif ( !defined $main_url_object{title} && $main_find_url_success == 1 ) {
		print "No url title found right before channel message\n";
	}
}

if ( defined $bot_username and $bot_username ne q() ) {

	if ( $body =~ /^!tell/ ) {
		if ( $body !~ /^!tell \S+ \S+/ or $body =~ /^!tell help/ ) {
			print "%$tell_help_text\n";
		}
		elsif ( $body =~ /^!tell in/ and $body !~ /!tell in \d+[smhd] / ) {
			print "%$tell_in_help_text\n";
		}
		else {
			#print time . "Calling tell_nick_command\n";
			tell_nick_command( $body, $who_said );
		}
	}
	if ( -f $tell_file ) {
		print localtime(time) . "\tCalling tell_nick\n";
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

exit 0;
