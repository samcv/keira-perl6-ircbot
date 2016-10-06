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
use Text::Unidecode;

binmode STDOUT, ':encoding(UTF-8)' or print "Failed to set binmode on STDOUT, Error $ERRNO\n";
our $VERSION = 0.4;
my $repo_url = 'https://gitlab.com/samcv/perlbot';
my ( $who_said, $body, $bot_username ) = @ARGV;

my ( $history_file, $tell_file, $channel_event_file );
my $history_file_length = 20;

my $help_text = 'Supports s/before/after (sed), !tell, and responds to .bots with bot info and '
	. 'repo url. Also posts the page title of any website pasted in channel';
my $welcome_text = "Welcome to the channel $who_said. We're friendly here, read the topic and please be patient.";

my $tell_help_text    = 'Usage: !tell nick "message to tell them"';
my $tell_in_help_text = 'Usage: !tell in 100d/h/m/s nickname \"message to tell them\"';

my $said_time = time;

if ( ( !defined $body ) or ( !defined $who_said ) ) {
	print "Did not receive any input\n";
	print "Usage: said.pl nickname \"text\" botname\n";
	exit 1;
}
else {
	utf8::decode($who_said);
	utf8::decode($body);
}

sub username_defined_pre {
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
	return;
}

sub process_seen {
	my ($fh) = @_;
	return;
}

sub seen_nick {
	my ( $seen_who_said, $seen_cmd ) = @_;
	my $nick = $seen_cmd;
	$nick =~ s/^!seen (\S+).*/$1/;
	my $event_file_exists = 0;
	my $is_in_file;
	my $return_string;

	open my $event_read_fh, '<', "$channel_event_file"
		or print "Could not open seen file, Error $ERRNO\n";
	binmode $event_read_fh, ':encoding(UTF-8)'
		or print 'Failed to set binmode on $event_read_fh, Error' . "$ERRNO\n";
	my @event_array = <$event_read_fh>;
	close $event_read_fh or print "Could not close seen file, Error $ERRNO\n";
	my %event_data;
	foreach my $line (@event_array) {
		chomp $line;
		my %event_file_data;

		if ( $line =~ m/^<(\S+?)> (\d+) (\d+) (\d+)/ ) {
			$event_file_data{who}      = $1;
			$event_file_data{chansaid} = $2;
			$event_file_data{chanjoin} = $3;
			$event_file_data{chanpart} = $4;
		}

		# If the nick matches we need to save the data
		if ( $nick =~ /^$event_file_data{who}?.?/i ) {
			$is_in_file = 1;
			%event_data = %event_file_data;
		}
	}
	if ( $is_in_file == 1 ) {
		$return_string = $event_data{who};

		my %text_strings = (
			chanjoin => ' Last joined: ',
			chanpart => ' Last parted/quit: ',
			chansaid => ' Last spoke: '
		);

		# Sort by most recent event and add each formatted line to the return string.
		foreach my $chan_event ( sort { $event_data{$b} <=> $event_data{$a} } keys %event_data ) {
			if ( $event_data{$chan_event} != 0 ) {
				$return_string = $return_string . $text_strings{$chan_event} . format_time( $event_data{$chan_event} );
			}
		}
		print "%$return_string\n";
	}
	return;
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

	my ( $tell_secs, $tell_mins, $tell_hours, $tell_days, $tell_years ) = convert_from_secs($tell_time_diff);
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

sub process_tell_nick {
	my ( $tell_write_fh, $tell_who_spoke, @tell_lines ) = @_;
	my $has_been_said = 0;
	my $tell_return;
	my ( $time_told, $time_to_tell, $tell_who_to_tell, $tell_what_to_tell );
	foreach my $tell_line (@tell_lines) {
		chomp $tell_line;

		if ( $tell_line =~ m/^(\d+) (\d+) <\S+?> >(\S+?)< (.*)/ ) {
			$time_told         = $1;
			$time_to_tell      = $2;
			$tell_who_to_tell  = $3;
			$tell_what_to_tell = $4;
		}

		if (   !$has_been_said && $time_to_tell < $said_time
			&& $tell_who_spoke =~ /$tell_who_to_tell/i )
		{
			$tell_return   = "<$tell_who_to_tell> >$tell_who_to_tell< $tell_what_to_tell " . format_time($time_told);
			$has_been_said = 1;
		}
		else {
			print {$tell_write_fh} "$tell_line\n";
		}
	}
	if ( defined $tell_return ) {
		return $tell_return;
	}
	return;
}

sub tell_nick {
	my ($tell_who_spoke) = @_;

	# Read
	open my $tell_read_fh, '<', "$tell_file"
		or print "Could not open $tell_file for read, Error $ERRNO\n";
	binmode $tell_read_fh, ':encoding(UTF-8)'
		or print 'Failed to set binmode on $tell_read_fh, Error' . "$ERRNO\n";
	my @tell_lines = <$tell_read_fh>;
	close $tell_read_fh or print "Could not close $tell_file, Error $ERRNO\n";

	# Write
	open my $tell_write_fh, '>', "$tell_file"
		or print "Could not open $tell_file for write, Error $ERRNO\n";
	binmode $tell_write_fh, ':encoding(UTF-8)'
		or print 'Failed to set binmode on $tell_fh, Error' . "$ERRNO\n";
	my $tell_return = process_tell_nick( $tell_write_fh, $tell_who_spoke, @tell_lines );

	close $tell_write_fh or print 'Could not close $tell_fh' . ", Error $ERRNO\n";
	if ( defined $tell_return ) {
		return $tell_return;
	}
	else {
		return;
	}
}

sub transliterate {
	my ( $transliterate_who, $transliterate_said ) = @_;
	$transliterate_said =~ s/^!transliterate\s*//;
	my $transliterate_return = unidecode($transliterate_said);
	print "%$transliterate_return\n";
	return;
}

sub tell_nick_command {
	my ( $tell_nick_body, $tell_who_spoke ) = @_;
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
			$tell_remind_when = unidecode($tell_remind_when);
			$tell_remind_time = $tell_remind_when * ONE_MINUTE + $said_time;
		}
		elsif ( $tell_remind_when =~ s/^(\d+)s$/$1/ ) {
			unidecode($tell_remind_when);
			$tell_remind_time = $tell_remind_when + $said_time;
		}
		elsif ( $tell_remind_when =~ s/^(\d+)d$/$1/ ) {
			unidecode($tell_remind_when);
			$tell_remind_time = $tell_remind_when * ONE_DAY + $said_time;
		}
		elsif ( $tell_remind_when =~ s/^(\d+)h$/$1/ ) {
			unidecode($tell_remind_when);
			$tell_remind_time = $tell_remind_when * ONE_HOUR + $said_time;
		}

	}
	else {
		$tell_who =~ s/!tell (\S+) .*/$1/;
		$tell_text =~ s/!tell \S+ (.*)/$1/;
	}
	print "tell_nick_time_called: $said_time tell_remind_time: $tell_remind_time "
		. "tell_who: $tell_who tell_text: $tell_text\n";

	open my $tell_fh, '>>', "$tell_file" or print "Could not open $tell_file, Error $ERRNO\n";
	binmode $tell_fh, ':encoding(UTF-8)'
		or print 'Failed to set binmode on $tell_fh, Error' . "$ERRNO\n";
	print {$tell_fh} "$said_time $tell_remind_time <$tell_who_spoke> >$tell_who< $tell_text\n"
		or print "Failed to append to $tell_file, Error $ERRNO\n";

	close $tell_fh or print "Could not close $tell_file, Error $ERRNO\n";
	return;
}

sub process_sed_replace {
	my ( $history_fh, $before_re, $after, $global ) = @_;

	my ( $replaced_who, $replaced_said );

	while ( defined( my $history_line = <$history_fh> ) ) {
		chomp $history_line;
		my $history_who = $history_line;
		$history_who =~ s{^<(.+?)>.*}{$1};
		my $history_said = $history_line;
		$history_said =~ s{^<.+?> }{};
		my $temp_replaced_said = $history_said;

		if (    $temp_replaced_said =~ m{$before_re}
			and $history_said !~ m{^s/}
			and $history_said !~ m{^!} )
		{
			if ($global) {
				$temp_replaced_said =~ s{$before_re}{$after}g;
			}
			else {
				$temp_replaced_said =~ s{$before_re}{$after}i;
			}
			if ( $history_said ne $temp_replaced_said ) {
				$replaced_said = $temp_replaced_said;
				$replaced_who  = $history_who;
			}
		}
	}
	return $replaced_who, $replaced_said;

}

sub sed_replace {
	my ($sed_called_text) = @_;
	my ( $before, $after );
	if ( $sed_called_text =~ m{^s/(.+?)/(.*)} ) {
		$before = $1;
		$after  = $2;
	}
	my $before_re = $before;
	my $global    = 0;

	if ( $after =~ s{/ig$}{} or s{/gi$}{} ) {
		$before_re = "(i?)$before";
		$global    = 1;
	}
	elsif ( $after =~ s{/i$}{} ) {
		$before_re = "(?i)$before";
	}
	elsif ( $after =~ s{/g$}{} ) {
		$global = 1;
	}
	else {
		# Remove a trailing slash if it remains
		$after =~ s{/$}{};
	}

	print "Before: $before\tAfter: $after\tRegex: $before_re \n";

	open my $history_fh, '<', "$history_file" or print "Could not open $history_file for read\n";
	binmode $history_fh, ':encoding(UTF-8)'
		or print 'Failed to set binmode on $history_fh, Error' . "$ERRNO\n";

	my ( $replaced_who, $replaced_said ) = process_sed_replace( $history_fh, $before_re, $after, $global );

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

sub process_curl {
	my ($CURL_OUT) = @_;
	my ( $is_text, $end_of_header, $is_404, $has_cookie, $is_cloudflare ) = (0) x 5;
	my ( $title_start_line, $title_between_line, $title_end_line ) = (0) x 3;
	my $new_location;
	my $title;
	my $line_no = 1;

	# REGEX
	my $title_text_regex  = '\s*(.*\S+)\s*';
	my $title_start_regex = '.*<title.*?>';
	my $title_end_regex   = '</title>.*';
	my @curl_title;
	while ( defined( my $curl_line = <$CURL_OUT> ) ) {

		# Processing done only within the header
		if ( $end_of_header == 0 ) {

			# Detect end of header
			if ( $curl_line =~ /^\s*$/ ) {
				$end_of_header = 1;
				if ( $is_text == 0 or defined $new_location ) {
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
	$title = join q(  ), @curl_title;

	my %process_object = (
		end_of_header    => $end_of_header,
		title            => $title,
		is_text          => $is_text,
		is_text          => $is_text,
		is_cloudflare    => $is_cloudflare,
		has_cookie       => $has_cookie,
		is_404           => $is_404,
		title_start_line => $title_start_line,
		title_end_line   => $title_end_line,
		line_no          => $line_no,
		new_location     => $new_location
	);

	return %process_object;
}

sub try_decode {
	my ($string) = @_;

	# Detect the encoding of the title with Encode::Detect module.
	eval { $string = decode( "Detect", $string ); };

	# If that fails fall back to using utf8::decode instead.
	($EVAL_ERROR) && utf8::decode($string);

	return $string;
}

sub get_url_title {
	my ($sub_url) = @_;
	print "Curl Location: \"$sub_url\"\n";
	my $curl_retry_times = 1;
	my $user_agent
		= 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/53.0.2785.116 Safari/537.36';
	my $curl_max_time = 5;
	my @curl_args     = (
		'--compressed', '-s',           '-H',          $user_agent, '--retry', $curl_retry_times,
		'--max-time',   $curl_max_time, '--no-buffer', '-i',        '--url',   $sub_url,
	);

	# Don't set BINMODE on curl's output because we will decode later on
	open3( undef, my $CURL_OUT, undef, 'curl', @curl_args )
		or print "Could not open curl pipe, Error $ERRNO\n";

	# Processing on the stream is done here
	my %new_object = process_curl($CURL_OUT);
	close $CURL_OUT or print "Could not close curl pipe, Error $ERRNO\n";

	# Print out $is_text and $title's values
	print "Ended on line $new_object{line_no}  "
		. 'Is Text: '
		. "$new_object{is_text}  "
		. 'End of Header: '
		. "$new_object{end_of_header}\n";
	if ( $new_object{title} and ( !defined $new_object{new_location} ) ) {
		my $title_length = $new_object{title_end_line} - $new_object{title_start_line};
		print 'Title Start Line: '
			. "$new_object{title_start_line}  "
			. 'Title End Line = '
			. $new_object{title_end_line}
			. " Lines from title start to end: $title_length\n";

		$new_object{title} = try_decode( $new_object{title} );

		# Decode html entities such as &nbsp
		$new_object{title} = decode_entities( $new_object{title} );

		# Replace carriage returns with two spaces
		$new_object{title} =~ s/\r/  /g;

		print "Title is: \"$new_object{title}\"\n";
	}
	$new_object{url} = $sub_url;

	return %new_object;
}

sub find_url {
	my ($find_url_caller_text) = @_;
	my ( $find_url_url, $new_location_text );
	my $max_title_length = 120;
	my $error_line       = 0;
	my @find_url_array   = extract_urls $find_url_caller_text;
	if ( $find_url_caller_text =~ m{\#\#\s*http.?://} ) {
		return 0;
	}
	foreach my $single_url (@find_url_array) {

		# Make sure we don't use FTP
		if ( $single_url !~ m{^ftp://}i ) {
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
			if ( $find_url_url !~ m{twitter[.]com/.+/status} ) {
				$url_object{title} = shorten_text( $url_object{title}, $max_title_length );
			}
			return ( 1, %url_object );
		}
		else {
			print "find_url return, it's not text or no title found\n";
			return 0;
		}
	}
	else {
		return 0;
	}
}

sub url_format_text {
	my ( $format_success, %url_format_object ) = @_;
	if ( $format_success != 1 || !defined $url_format_object{title} ) {
		return 0;
	}
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
		return 1, "[ $url_format_object{title} ]" . $new_location_text . $cloudflare_text . $cookie_text;
	}
	else {
		return 0;
	}
}

sub shorten_text {
	my ( $long_text, $max_length ) = @_;
	if ( !defined $max_length ) { $max_length = 250 }
	my $short_text = substr $long_text, 0, $max_length;
	if ( $long_text ne $short_text ) {
		return $short_text . ' ...';
	}
	else {
		return $long_text;
	}

}

sub rephrase {
	my ($phrase) = @_;
	my $the = 0;
	if ( $phrase =~ /^\s*is\b\s*/i ) {
		$phrase =~ s/^\s*is\b\s*//i;
		if ( $phrase =~ s/^\s*\bthe\b//i ) {
			$the = 1;
		}
		$phrase =~ s/(\b\S+\b)(.*)/$1 is$2/;
		if ($the) {
			$phrase = 'the' . $phrase;
		}
		return ucfirst $phrase;
	}
	else {
		return ucfirst $phrase;
	}
}

sub bot_coin {
	my ( $coin_who, $coin_said ) = @_;
	my $coin       = int rand 2;
	my $coin_3     = int rand 3;
	my $thing_said = $coin_said;
	$thing_said =~ s/^$bot_username\S?\s*//;
	$thing_said =~ s/[?]//g;

	if ( $coin_said =~ /\bor\b/ ) {
		my $count_or;
		my $word = 'or';
		while ( $coin_said =~ /\b$word\b/g ) {
			++$count_or;
		}
		print "There are $count_or instances of 'or'\n";
		if ( $count_or > 2 ) {
			print "%I don't support asking more than three things at once... yet\n";
		}
		elsif ( $count_or == 2 ) {
			$thing_said =~ m/^\s*(.*)\s*\bor\b\s*(.*)\s*\bor\b\s*(.*)\s*$/;
			print "One: $1 Two: $2 Three: $3\n";
			if ( $coin_3 == 0 ) {
				$thing_said = rephrase($1);
				print "%$thing_said\n";
			}
			elsif ( $coin_3 == 1 ) {
				$thing_said = rephrase($2);
				print "%$thing_said\n";
			}
			elsif ( $coin_3 == 2 ) {
				$thing_said = rephrase($3);
				print "%$thing_said\n";
			}
		}
		else {
			if ($coin) {
				$thing_said =~ s/\s*\bor\b.*//;
				$thing_said = rephrase($thing_said);
				print "%$thing_said\n";
			}
			else {
				$thing_said =~ s/.*\bor\b\s*//;
				$thing_said = rephrase($thing_said);
				print "%$thing_said\n";
			}
		}
	}
	else {
		if   ($coin) { print "%Yes: $thing_said\n" }
		else         { print "%No: $thing_said\n" }
	}
	return;
}

sub addressed {
	my ( $addressed_who, $addressed_said ) = @_;

	return;
}

sub trunicate_history {
	system("tail -n $history_file_length ./$history_file | sponge ./$history_file")
		or print "Problem with tail ./$history_file | sponge ./$history_file, Error $ERRNO\n";
	return;
}

sub username_defined_post {

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
	trunicate_history;
	return;
}

# MAIN
if ( defined $bot_username and $bot_username ne q() ) {
	username_defined_pre;

}

# .bots reporting functionality
if ( $body =~ /[.]bots.*/ ) {
	print "%$bot_username reporting in! [perl] $repo_url v$VERSION\n";
}

# If the bot is addressed by name, call this function
if ( $body =~ /$bot_username/ ) {
	if ( $body =~ /[?]/ ) {
		bot_coin( $who_said, $body );
	}
	else {
		addressed( $who_said, $body );
	}
}

# Sed functionality. Only called if the history file is defined
elsif ( $body =~ m{^s/.+/}i and defined $history_file ) {
	my ( $sed_who, $sed_text ) = sed_replace($body);
	$sed_text = shorten_text($sed_text);

	if ( defined $sed_who and defined $sed_text ) {
		print "sed_who: $sed_who sed_text: $sed_text\n";
		print "%<$sed_who> $sed_text\n";
	}
}
elsif ( $body =~ /^!transliterate/ ) {
	transliterate( $who_said, $body );
}

elsif ( $body =~ /^!help/i ) {
	print "%$help_text\n";
}

# Find and get URL's page title
my ( $url_format_return, $main_url_formatted_text ) = url_format_text( find_url($body) );
if ($url_format_return) {
	print "%$main_url_formatted_text\n";
}

else {
	print "No url title or no success found right before channel message\n";
}

if ( defined $bot_username and $bot_username ne q() ) {
	username_defined_post;
}

exit 0;
