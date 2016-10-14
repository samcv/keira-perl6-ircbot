#!/usr/bin/env perl
# said perlbot script
use strict;
use warnings;
use HTML::Entities 'decode_entities';
use IPC::Open3 'open3';
use Encode;
use Symbol 'gensym';
use Encode::Detect;
use feature 'unicode_strings';
use POSIX ":sys_wait_h";
use utf8;
use English;
use Time::Seconds;
use URL::Search 'extract_urls';
use Text::Unidecode;
use Convert::EastAsianWidth;

binmode STDOUT, ':encoding(UTF-8)'
	or print_stderr("Failed to set binmode on STDOUT, Error $ERRNO");
binmode STDERR, ':encoding(UTF-8)'
	or print_stderr("Failed to set binmode on STDERR, Error $ERRNO");

our $VERSION = 0.5;
my $repo_url = 'https://gitlab.com/samcv/perlbot';
my ( $who_said, $body, $bot_username, $channel ) = @ARGV;

my ( $history_file, $tell_file, $channel_event_file );
my $history_file_length = 20;

my $help_text
	= 'Supports s/before/after (sed), !tell, and responds to .bots with bot info and '
	. 'repo url. !u to get unicode hex codepoints for a string. !unicode to convert hex '
	. 'codepoints to unicode. !tohex and !fromhex !transliterate to transliterate most '
	. 'languages into romazied text. !tell or !tell in 1s/m/h/d to tell somebody a message '
	. 'triggered on them speaking. !seen to get last spoke/join/part of a user. s/before/after '
	. 'perl style regex text substitution. !ud to get Urban Dictionary definitions. Also posts '
	. 'the page title of any website pasted in channel and if you address the bot by name and use '
	. 'a ? it will answer the question. Supports !perl to evaluate perl code.';

my $welcome_text = "Welcome to the channel $who_said. We're friendly here, read the topic and please be patient.";

my $tell_help_text    = 'Usage: !tell nick "message to tell them"';
my $tell_in_help_text = 'Usage: !tell in 100d/h/m/s nickname "message to tell them"';
my $EMPTY             = q{};
my $SPACE             = q{ };

my %style_table = (
	bold      => chr 2,
	italic    => chr 29,
	underline => chr 31,
	reset     => chr 15,
	reverse   => chr 22,
	color     => chr 3,

);

my %control_codes = (
	NULL => chr 0,
	A    => chr 1,
	B    => chr 2,
	C    => chr 3,
	D    => chr 4,
	E    => chr 5,
	F    => chr 6,
	G    => chr 7,
	H    => chr 8,
	I    => chr 9,
	J    => chr 10,
	K    => chr 11,
	L    => chr 12,
	M    => chr 13,
	N    => chr 14,
	O    => chr 15,
	P    => chr 16,
	Q    => chr 17,
	R    => chr 18,
	S    => chr 19,
	T    => chr 20,
	U    => chr 21,
	V    => chr 22,
	W    => chr 23,
	X    => chr 24,
	Y    => chr 25,
	Z    => chr 26,
	DEL  => chr 127,
);

my $said_time = time;

if ( !defined $body || !defined $who_said ) {
	print_stderr(q/Did not receive any input/);
	print_stderr(q/Usage: said.pl nickname "text" bot_username channel/);
	exit 1;
}
else {
	utf8::decode($who_said);
	utf8::decode($body);
	if ( defined $channel ) { utf8::decode($channel) }
}

sub print_stderr {
	my ( $error_text, $error_level ) = @_;
	chomp $error_text;
	if ( defined $error_text and $error_text ne $EMPTY ) {
		print {*STDERR} $error_text . "\n";
		return 0;
	}
	else {
		print_stderr('Undefined or empty error message.');
	}
	return 1;
}

sub msg_channel {
	my ($channel_msg_text) = @_;
	print_stderr("CHANNEL_MSG_TEXT: $channel_msg_text");
	print q(%) . $channel_msg_text . "\n" or print_stderr($ERRNO);
	return 0;
}

sub private_message {
	my ( $pm_who, $pm_text ) = @_;
	if ( defined $pm_who && defined $pm_text ) {
		print q($) . $pm_who . q(%) . $pm_text . "\n" and return 1;
	}

	return 0;
}

sub msg_same_origin {
	my ( $so_msg_who, $so_msg_text ) = @_;
	print_stderr("CHANNEL: $channel SO_MSG_WHO: $so_msg_who SO_MSG_TEXT: $so_msg_text");
	if ( !defined $so_msg_text || $so_msg_text eq $EMPTY ) {
		print_stderr('Not defined or empty message in msg_same_origin');
		return 0;
	}
	if ( !defined $so_msg_who || $so_msg_who eq $EMPTY ) {
		print_stderr('Did not receive $so_msg_who, falling back to $who_said by private message');
		private_message( $who_said, $so_msg_text );
		return 0;
	}
	if ( $channel eq 'msg' ) {
		private_message( $so_msg_who, $so_msg_text ) and return 1;
	}
	if ( defined $channel and $channel ne $EMPTY and $channel ne 'msg' ) {
		msg_channel($so_msg_text) and return 1;
	}
	else {
		print_stderr(q/Channel is not defined, Assuming this is a test so printing to 'channel'/);
		msg_channel($so_msg_text) and return 1;
	}
	return 0;
}

sub write_to_history {

	# Add line to history file
	open my $history_fh, '>>', "$history_file"
		or print_stderr("Could not open history file, Error $ERRNO");
	binmode $history_fh, ':encoding(UTF-8)'
		or print_stderr("Failed to set binmode on history_fh, Error $ERRNO");

	print {$history_fh} "<$who_said> $body\n"
		or print_stderr("Failed to append to $history_file, Error $ERRNO");
	close $history_fh or print_stderr("Could not close $history_file, Error $ERRNO");
	return;
}

sub var_ne {
	my ( $var_ne_var, $var_ne_test ) = @_;
	if ( !defined $var_ne_var ) {
		return 0;
	}
	elsif ( $var_ne_var ne $var_ne_test ) {
		return 1;
	}
	return 0;
}

sub username_defined_pre {
	$history_file       = $bot_username . '_history.txt';
	$tell_file          = $bot_username . '_tell.txt';
	$channel_event_file = $bot_username . '_event.txt';

	$history_file_length = 20;
	utf8::decode($bot_username);

	if ( var_ne( $channel, 'msg' ) ) { write_to_history() }

	return;
}

sub format_action {
	my ( $action_who, $action_text ) = @_;
	$action_text = "\cA" . 'ACTION' . $SPACE . $action_text . "\cA";
	msg_same_origin( $action_who, $action_text ) and return 1;
	return 0;

}

sub text_style {
	my ( $string, $effect, $foreground, $background ) = @_;
	my %color_table = (
		white       => '00',
		black       => '01',
		blue        => '02',
		green       => '03',
		red         => '04',
		brown       => '05',
		purple      => '06',
		orange      => '07',
		yellow      => '08',
		light_green => '09',
		teal        => '10',
		light_cyan  => '11',
		light_blue  => '12',
		pink        => '13',
		grey        => '14',
		light_grey  => '15',
	);
	if ( defined $background and defined $foreground ) {
		$string
			= $style_table{color}
			. $color_table{$foreground} . q(,)
			. $color_table{$background}
			. $string
			. $style_table{reset};
	}
	elsif ( defined $foreground ) {
		$string = $style_table{color} . $color_table{$foreground} . $string . $style_table{color};
	}
	if ( defined $effect ) {
		$string = $style_table{$effect} . $string . $style_table{reset};
	}
	$string =~ s/$style_table{reset}+/$style_table{reset}/g;
	$string =~ s/$style_table{reset}+/$style_table{color}/g;

	return $string;

}

sub from_hex {
	my ( $from_hex_who, $from_hex_said ) = @_;
	$from_hex_said =~ s/0x//g;
	my @decimals = split $SPACE, $from_hex_said;
	my $hex_string;
	foreach my $decimal (@decimals) {
		$hex_string .= hex($decimal) . $SPACE;
	}
	msg_same_origin( $from_hex_who, $hex_string ) and return 1;
	return 0;
}

sub to_hex {
	my ( $to_hex_who, $to_hex_said ) = @_;
	my @hexes = split $SPACE, $to_hex_said;
	my $dec_string;
	foreach my $hex (@hexes) {
		$dec_string .= sprintf '%x ', $hex;
	}
	$dec_string = uc $dec_string;
	msg_same_origin( $to_hex_who, $dec_string ) and return 1;
	return 0;
}

sub uppercase {
	my ( $uc_who, $uc_said ) = @_;
	msg_same_origin( $uc_who, uc $uc_said ) and return 1;
	return 0;
}

sub uppercase_irc {
	my ( $uc_irc_who, $uc_irc_said ) = @_;
	$uc_irc_said =~ tr/{}|/\[\]\\/;
	msg_same_origin( $uc_irc_who, uc $uc_irc_said ) and return 1;
	return 0;
}

sub lowercase {
	my ( $lc_who, $lc_said ) = @_;
	msg_same_origin( $lc_who, lc $lc_said ) and return 1;
	return 0;
}

sub lowercase_irc {
	my ( $lc_irc_who, $lc_irc_said ) = @_;
	$lc_irc_said =~ tr/\[\]\\/{}|/;
	msg_same_origin( $lc_irc_who, lc $lc_irc_said ) and return 1;
	return 0;
}

sub seen_nick {
	my ( $seen_who_said, $seen_cmd ) = @_;
	my $nick = $seen_cmd;
	$nick =~ s/^!seen (\S+).*/$1/;
	my $event_file_exists = 0;
	my $is_in_file;
	my $return_string;

	open my $event_read_fh, '<', "$channel_event_file"
		or print_stderr("Could not open seen file, Error $ERRNO");
	binmode $event_read_fh, ':encoding(UTF-8)'
		or print_stderr("Failed to set binmode on event_read_fh, Error $ERRNO");
	my @event_array = <$event_read_fh>;
	close $event_read_fh or print_stderr("Could not close seen file, Error $ERRNO");
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
			chansaid => ' Last spoke: ',
		);

		# Sort by most recent event and add each formatted line to the return string.
		foreach my $chan_event ( reverse sort { $event_data{$a} <=> $event_data{$b} } keys %event_data ) {
			if ( $event_data{$chan_event} != 0 ) {
				$return_string .= $text_strings{$chan_event} . format_time( $event_data{$chan_event} );
			}
		}
		msg_same_origin( $seen_who_said, $return_string ) and return 1;
	}
	return 0;
}

sub try_decode {
	my ($string) = @_;

	# Detect the encoding of the title with Encode::Detect module.
	# If that fails fall back to using utf8::decode instead.
	if ( !eval { $string = decode( 'Detect', $string ); 1 } ) {
		utf8::decode($string);
	}

	return $string;
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
		$tell_return .= $tell_years . 'y ';
	}
	if ( defined $tell_days ) {
		$tell_return .= $tell_days . 'd ';
	}
	if ( defined $tell_hours ) {
		$tell_return .= $tell_hours . 'h ';
	}
	if ( defined $tell_mins ) {
		$tell_return .= $tell_mins . 'm ';
	}
	if ( defined $tell_secs ) {
		$tell_return .= $tell_secs . 's ';
	}
	$tell_return .= 'ago]';
	return $tell_return;
}

sub process_tell_nick {
	my ( $tell_write_fh, $tell_who_spoke, @tell_lines ) = @_;
	my $has_been_said = 0;
	my $tell_return;
	my ( $time_told, $time_to_tell, $who_told, $who_to_tell, $what_to_tell );
	foreach my $tell_line (@tell_lines) {
		chomp $tell_line;

		if ( $tell_line =~ m/^(\d+) (\d+) <(\S+?)> >(\S+?)< (.*)/ ) {
			$time_told    = $1;
			$time_to_tell = $2;
			$who_told     = $3;
			$who_to_tell  = $4;
			$what_to_tell = $5;
		}

		if (  !$has_been_said
			&& $time_to_tell < $said_time
			&& $tell_who_spoke =~ /$who_to_tell/i )
		{
			$tell_return   = "<$who_told> >$who_to_tell< $what_to_tell " . format_time($time_told);
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
		or print_stderr("Could not open $tell_file for read, Error $ERRNO");
	binmode $tell_read_fh, ':encoding(UTF-8)'
		or print_stderr("Failed to set binmode on tell_read_fh, Error, $ERRNO");
	my @tell_lines = <$tell_read_fh>;
	close $tell_read_fh or print_stderr("Could not close $tell_file, Error $ERRNO");

	# Write
	open my $tell_write_fh, '>', "$tell_file"
		or print_stderr("Could not open $tell_file for write, Error $ERRNO");
	binmode $tell_write_fh, ':encoding(UTF-8)'
		or print_stderr("Failed to set binmode on tell_fh, Error $ERRNO");
	my $tell_return = process_tell_nick( $tell_write_fh, $tell_who_spoke, @tell_lines );

	close $tell_write_fh or print_stderr("Could not close tell_fh, Error $ERRNO");
	if ( defined $tell_return ) {
		return $tell_return;
	}
	else {
		return;
	}
}

sub transliterate {
	my ( $transliterate_who, $transliterate_said ) = @_;
	my $transliterate_return = unidecode($transliterate_said);
	msg_same_origin( $transliterate_who, $transliterate_return ) and return 1;

	return 0;
}

sub tell_nick_command {
	my ( $tell_who_spoke, $tell_nick_body ) = @_;
	chomp $tell_nick_body;
	my $tell_remind_time         = 0;
	my $tell_nick_command_return = 0;

	if ( $body !~ /^\S+ \S+/ or $body =~ /^help/ ) {
		msg_same_origin( $who_said, $tell_help_text ) and return 1;
	}
	elsif ( $body =~ /^in/ and $body !~ /^in \d+[smhd] / ) {
		msg_same_origin( $who_said, $tell_in_help_text ) and return 1;
	}
	else {
		my $tell_who         = $tell_nick_body;
		my $tell_text        = $tell_nick_body;
		my $tell_remind_when = $tell_nick_body;
		if ( $tell_nick_body =~ m/^in (\S+) (\S+) (.*)/ or $tell_nick_body =~ /^!tell help/ ) {
			$tell_remind_when = $1;
			$tell_who         = $2;
			$tell_text        = $3;

			if ( $tell_remind_when =~ s/^(\d+)s$/$1/ ) {
				unidecode($tell_remind_when);
				$tell_remind_time = $tell_remind_when + $said_time;
			}
			elsif ( $tell_remind_when =~ s/^(\d+)m$/$1/ ) {
				unidecode($tell_remind_when);
				$tell_remind_time = $tell_remind_when * ONE_MINUTE + $said_time;
			}
			elsif ( $tell_remind_when =~ s/^(\d+)h$/$1/ ) {
				unidecode($tell_remind_when);
				$tell_remind_time = $tell_remind_when * ONE_HOUR + $said_time;
			}
			elsif ( $tell_remind_when =~ s/^(\d+)d$/$1/ ) {
				unidecode($tell_remind_when);
				$tell_remind_time = $tell_remind_when * ONE_DAY + $said_time;
			}

		}
		else {
			$tell_who =~ s/^(\S+) .*/$1/;
			$tell_text =~ s/^\S+ (.*)/$1/;
		}
		print_stderr( "tell_nick_time_called: $said_time tell_remind_time: $tell_remind_time "
				. "tell_who: $tell_who tell_text: $tell_text" );

		open my $tell_fh, '>>', "$tell_file" or print_stderr("Could not open $tell_file, Error $ERRNO");
		binmode $tell_fh, ':encoding(UTF-8)'
			or print_stderr("Failed to set binmode on tell_fh, Error, $ERRNO");
		if ( print {$tell_fh} "$said_time $tell_remind_time <$tell_who_spoke> >$tell_who< $tell_text\n" ) {
			$tell_nick_command_return = 1;
		}
		else {
			print_stderr("Failed to append to $tell_file, Error $ERRNO");
		}
		close $tell_fh or print_stderr("Could not close $tell_file, Error $ERRNO");
	}
	return $tell_nick_command_return;
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
		my $replaced_said_temp = $history_said;

		if (    $replaced_said_temp =~ m{$before_re}
			and $history_said !~ m{^s/}
			and $history_said !~ m{^!} )
		{
			if ($global) {
				$replaced_said_temp =~ s{$before_re}{$after}g;
			}
			else {
				$replaced_said_temp =~ s{$before_re}{$after}i;
			}
			if ( $history_said ne $replaced_said_temp ) {
				$replaced_said = $replaced_said_temp;
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

	print_stderr("Before: $before\tAfter: $after\tRegex: $before_re");
	my ( $replaced_who, $replaced_said );
	print_stderr('Trying to open history file');
	if ( open my $history_fh, '<', "$history_file" ) {
		print_stderr('Successfully opened history file');
		binmode $history_fh, ':encoding(UTF-8)'
			or print_stderr( 'Failed to set binmode on $history_fh, Error' . "$ERRNO" );

		( $replaced_who, $replaced_said ) = process_sed_replace( $history_fh, $before_re, $after, $global );

		close $history_fh or print_stderr("Could not close $history_file, Error: $ERRNO");
	}
	else {
		print_stderr("Could not open $history_file for read");
	}

	if ( defined $replaced_said && defined $replaced_who ) {
		print_stderr("replaced_said: $replaced_said replaced_who: $replaced_who");
		open my $history_fh, '>>', "$history_file"
			or print_stderr("Could not open $history_file for write");
		binmode $history_fh, ':encoding(UTF-8)'
			or print_stderr( 'Failed to set binmode on $history_fh, Error' . "$ERRNO" );
		print {$history_fh} '<' . $replaced_who . '> ' . $replaced_said . "\n";
		close $history_fh or print_stderr("Could not close $history_file, Error: $ERRNO");
		return $replaced_who, $replaced_said;
	}
}

sub process_curl {
	my ( $curl_pid, $CURL_OUT, $CURL_STDERR ) = @_;
	my %process = (
		end_of_header      => 0,
		is_text            => 0,
		is_cloudflare      => 0,
		has_cookie         => 0,
		is_404             => 0,
		title_start_line   => 0,
		title_end_line     => 0,
		title_between_line => 0,
		line_no            => 1,
	);

	# REGEX
	my $title_text_regex  = '\s*(.*\S+)\s*';
	my $title_start_regex = '.*<title.*?>';
	my $title_end_regex   = '</title>.*';
	my @curl_title;

	#while ( defined( my $curl_line = <$CURL_OUT> ) or defined( my $curl_error_line = <$CURL_STDERR> ) ) {

	while ( defined( my $curl_line = <$CURL_OUT> ) ) {

		# Processing done only within the header
		if ( $process{end_of_header} == 0 and defined $curl_line ) {

			# Detect end of header
			if ( $curl_line =~ /^\s*$/ ) {
				$process{end_of_header} = 1;
				if ( $process{is_text} == 0 or defined $process{new_location} ) {
					print_stderr(q/Stopping because it's not text or a new location is defined/);
					last;
				}
			}

			# Detect content type
			elsif ( $curl_line =~ /^Content-Type:.*text/i )       { $process{is_text}       = 1 }
			elsif ( $curl_line =~ /^CF-RAY:/i )                   { $process{is_cloudflare} = 1 }
			elsif ( $curl_line =~ /^Set-Cookie.*/i )              { $process{has_cookie}++ }
			elsif ( $curl_line =~ s/^Location:\s*(\S*)\s*$/$1/i ) { $process{new_location}  = $curl_line }
		}

		# Processing done after the header
		elsif ( defined $curl_line ) {

			# Find the <title> element
			if ( $curl_line =~ s{$title_start_regex}{}i ) {
				$process{title_start_line} = $process{line_no};
			}

			# Find the </title> element
			if ( $curl_line =~ s{$title_end_regex}{}i ) {
				$process{title_end_line} = $process{line_no};
			}

			# If we are between <title> and </title>
			elsif ( $process{title_start_line} != 0 && $process{title_end_line} == 0 ) {
				$process{title_between_line} = $process{line_no};
			}

			if (   $process{title_start_line}
				or $process{title_end_line}
				or $process{title_between_line} == $process{line_no} )
			{
				$curl_line =~ s{$title_text_regex}{$1};
				if ( $curl_line !~ /^\s*$/ ) {
					push @curl_title, $curl_line;
					print_stderr(qq(Line $process{line_no} is "$curl_line"));
				}
			}

			# If we reach the </head>, <body> have reached the end of title
			if ( $curl_line =~ m{</head>} or $curl_line =~ m{<body.*?>} or $process{title_end_line} != 0 ) {
				last;
			}
		}

		$process{line_no}++;
	}

	#$process{curl_return} = $? >> 8;
	#print_stderr("$process{curl_return} in process");

	if (@curl_title) { $process{curl_title} = \@curl_title }
	my $return = \%process;
	return \%process;
}

sub get_url_title {
	my ( $sub_url, $curl_unsafe_ssl ) = @_;
	print_stderr(qq(Curl Location: "$sub_url"));
	my $user_agent
		= 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) '
		. 'AppleWebKit/537.36 (KHTML, like Gecko) '
		. 'Chrome/53.0.2785.116 Safari/537.36';
	my @curl_unsafe_ssl_flags = ('-k');

	if ( !defined $curl_unsafe_ssl ) {
		$curl_unsafe_ssl = 'NO';
	}

	#$curl_unsafe_ssl = $EMPTY;
	my $curl_max_time    = 5;
	my $curl_retry_times = 1;
	my @curl_args;
	@curl_args = (
		'--compressed', '-H',          $user_agent, '--retry', $curl_retry_times, '--max-time',
		$curl_max_time, '--no-buffer', '-i',        '--url',   $sub_url
	);
	if ( $curl_unsafe_ssl eq 'UNSAFE_SSL' ) {
		print_stderr("UNSAFE Setting curl unsafe-ssl to $curl_unsafe_ssl");
		unshift @curl_args, @curl_unsafe_ssl_flags;
		print "trying to unshift\n";
	}
	foreach (@curl_args) {
		print " $_";
	}

	my $title;
	my ( $CURL_STDERR, $CURL_STDIN, $CURL_OUT );

	# If we don't set this sometimes weird things happen and filehandles could get combined
	#$CURL_STDERR = gensym;

	# Don't set BINMODE on curl's output because we will decode later on
	#my $curl_pid = open3( $CURL_STDIN, $CURL_OUT, $CURL_STDERR, 'curl', @curl_args )
	my $curl_pid = open( $CURL_OUT, '-|', 'curl', @curl_args )
		or print_stderr("Could not open curl pipe, Error $ERRNO");

	# Processing on the stream is done here
	my %new_object = %{ process_curl( $curl_pid, $CURL_OUT, $CURL_STDERR ) };

	#	my %new_object = %{ process_curl( $curl_pid, $CURL_OUT, $CURL_STDERR ) };

	if ( defined $CURL_OUT ) {
		if ( $CURL_OUT->opened ) {
			close $CURL_OUT
				or print_stderr("Could not close curl out pipe, Error $ERRNO");
			if ( !defined $new_object{curl_return} ) {
				$new_object{curl_return} = $? >> 8;
			}
		}
	}
	if ( defined $CURL_STDIN ) {
		if ( $CURL_STDIN->opened ) {
			close $CURL_STDIN or print_stderr("Could not close curl in pipe, Error $ERRNO");
		}
		if ( !defined $new_object{curl_return} ) {
			$new_object{curl_return} = $? >> 8;
		}
	}
	if ( defined $CURL_STDERR ) {
		if ( $CURL_STDIN->opened ) {
			close $CURL_STDERR or print_stderr("Could not close curl stderr pipe, Error $ERRNO");
			if ( !defined $new_object{curl_return} ) {
				$new_object{curl_return} = $? >> 8;
			}
		}
	}
	my $curl_return = $new_object{curl_return};
	print_stderr("Curl return is $curl_return");
	if ( $curl_return == 0 ) {

		# Print out $process{is_text} and $title's values
		print_stderr( "Ended on line $new_object{line_no}  "
				. 'Is Text: '
				. "$new_object{is_text}  "
				. 'End of Header: '
				. "$new_object{end_of_header}  "
				. "ssl error: $new_object{ssl_error}" );

		my $title_length = $new_object{title_end_line} - $new_object{title_start_line};
		print_stderr( 'Title Start Line: '
				. "$new_object{title_start_line}  "
				. 'Title End Line = '
				. $new_object{title_end_line}
				. " Lines from title start to end: $title_length" );
	}
	else {
		print_stderr("There was a problem with curl.  Error code $new_object{curl_return}");

	}

	print_stderr("There was a problem with curl.  Error code $new_object{curl_return}");

	if ( !defined $new_object{new_location} && defined $new_object{curl_title} ) {
		$title = join q(  ), @{ $new_object{curl_title} };
		$title = try_decode($title);

		# Decode html entities such as &nbsp
		$title = decode_entities($title);

		# Replace carriage returns with two spaces
		$title =~ s/\r/  /g;

		print_stderr(qq(Title is: "$title"));
	}
	$new_object{url}   = $sub_url;
	$new_object{title} = $title;
	$curl_return       = $new_object{curl_return};
	print "$curl_return\n";
	$new_object{curl_return} = \$curl_return;

	return \%new_object;
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
			print_stderr("Found $find_url_url as the first url");
			last;
		}
	}

	if ( defined $find_url_url ) {

		if ( $find_url_url =~ m/;/ ) {
			print_stderr('URL has comma(s) in it. Error.');
			$find_url_url =~ s/;/%3B/xmsg;
			return 0;
		}
		elsif ( $find_url_url =~ m/\$/ ) {
			print_stderr('URL has $ sign in it. Error.');
			return 0;
		}
		my $url_new_location;

		my %url_object = %{ get_url_title($find_url_url) };

		my $redirects = 0;
		while ( defined $url_object{new_location} and $redirects < 3 ) {
			$redirects++;
			if ( defined $url_object{new_location} ) {
				$url_new_location = $url_object{new_location};
				%url_object       = %{ get_url_title($url_new_location) };
			}
		}
		my $return_code  = ${ $url_object{curl_return} };
		my $return_tries = 0;
		my $bad_ssl;
		print "RETURN CODE IS $return_code\n";
		if (   $return_code == 35
			or $return_code == 51
			or $return_code == 53
			or $return_code == 54
			or $return_code == 58
			or $return_code == 59
			or $return_code == 60
			or $return_code == 64
			or $return_code == 66
			or $return_code == 77
			or $return_code == 82
			or $return_code == 83
			or $return_code == 90
			or $return_code == 91 )
		{
			print "RETURN CODE MATCH FOR BAD SSL LOOP\n";
			while ( defined $url_object{curl_return} and $return_tries < 2 ) {
				$bad_ssl = 'BAD_SSL';
				if ( $url_object{curl_return} == 0 or $url_object{curl_return} == 23 ) {last}
				if ( defined $url_new_location ) {
					%url_object = %{ get_url_title( $url_new_location, 'UNSAFE_SSL' ) };
				}
				else {
					print "getting bad ssl page\n";
					%url_object = %{ get_url_title( $find_url_caller_text, 'UNSAFE_SSL' ) };
				}
				$return_tries++;
			}
		}
		if ($return_tries) {
			$url_object{curl_return} = \$return_code;
		}
		$url_object{new_location} = $url_new_location;

		if ( $url_object{is_text} && defined $url_object{title} || $url_object{curl_return} != 0 ) {
			if ( $find_url_url !~ m{twitter[.]com/.+/status} or m{reddit[.]com/} ) {
				$url_object{title} = shorten_text( $url_object{title}, $max_title_length );
			}
			return ( 1, \%url_object, $bad_ssl );
		}
		else {
			print_stderr(q/find_url return, it's not text or no title found/);
			return 0;
		}
	}
	else {
		return 0;
	}
}

sub url_format_text {
	my ( $format_success, $ref, $bad_ssl ) = @_;
	my %url_format_object;
	if ( defined $ref ) {
		%url_format_object = %{$ref};
	}
	else {
		print_stderr('$ref is not defined!!!');
	}
	my %curl_exit_codes = (
		1 => "CURLE_UNSUPPORTED_PROTOCOL The URL you passed to libcurl used a protocol that this "
			. "libcurl does not support. The support might be a compile-time option that you "
			. "didn't use, it can be a misspelled protocol string or just a protocol libcurl "
			. "has no code for.",
		2 => "CURLE_FAILED_INIT Very early initialization code failed. This is likely to be an "
			. "internal error or problem, or a resource problem where something fundamental "
			. "couldn't get done at init time.",
		3 => 'CURLE_URL_MALFORMAT The URL was not properly formatted.',
		4 => 'CURLE_NOT_BUILT_IN A requested feature, protocol or option was not found built-in '
			. 'in this libcurl due to a build-time decision. This means that a feature or option '
			. 'was not enabled or explicitly disabled when libcurl was built and in order to '
			. 'get it to function you have to get a rebuilt libcurl.',
		5 => "CURLE_COULDNT_RESOLVE_PROXY Couldn't resolve proxy. The given proxy host could "
			. "not be resolved.",
		6 => "CURLE_COULDNT_RESOLVE_HOST Couldn't resolve host. The given remote host was not resolved.",
		7 => 'CURLE_COULDNT_CONNECT Failed to connect() to host or proxy.',
		8 => "CURLE_FTP_WEIRD_SERVER_REPLY The server sent data libcurl couldn't parse. This "
			. "error code is used for more than just FTP",
		9 => 'CURLE_REMOTE_ACCESS_DENIED We were denied access to the resource given in the URL. '
			. 'For FTP, this occurs while trying to change to the remote directory.',
		10 => 'CURLE_FTP_ACCEPT_FAILED',
		11 => 'CURLE_FTP_WEIRD_PASS_REPLY',
		12 => 'CURLE_FTP_ACCEPT_TIMEOUT',
		13 => 'CURLE_FTP_WEIRD_PASV_REPLY',
		14 => 'CURLE_FTP_WEIRD_227_FORMAT',
		15 => 'CURLE_FTP_CANT_GET_HOST',
		16 => 'CURLE_HTTP2',
		17 => 'CURLE_FTP_COULDNT_SET_TYPE',
		18 => 'CURLE_PARTIAL_FILE',
		19 => 'CURLE_FTP_COULDNT_RETR_FILE',
		21 => 'CURLE_QUOTE_ERROR',
		22 => 'CURLE_HTTP_RETURNED_ERROR',
		23 => "CURLE_WRITE_ERROR An error occurred when writing received data to a local file, or "
			. "an error was returned to libcurl from a write callback.",
		35 => 'CURLE_SSL_CONNECT_ERROR A problem occurred somewhere in the SSL/TLS handshake. '
			. "Curl probably doesn't support this type of crypto.",
		43 => 'CURLE_BAD_FUNCTION_ARGUMENT Internal error. A function was called with a bad parameter.',
		45 => "CURLE_INTERFACE_FAILED Interface error. A specified outgoing interface could not be "
			. "used. Set which interface to use for outgoing connections' source IP address with "
			. "CURLOPT_INTERFACE.",
		51 => "CURLE_PEER_FAILED_VERIFICATION The remote server's SSL certificate or SSH md5 "
			. "fingerprint was deemed not OK.",
		53 => "CURLE_SSL_ENGINE_NOTFOUND The specified crypto engine wasn't found.",
		54 => 'CURLE_SSL_ENGINE_SETFAILED Failed setting the selected SSL crypto engine as default!',
		58 => 'CURLE_SSL_CERTPROBLEM Problem with the local client certificate.',
		59 => "CURLE_SSL_CIPHER Couldn't use specified cipher.",
		60 => 'CURLE_SSL_CACERT Peer certificate cannot be authenticated with known CA certificates.',
		64 => 'CURLE_USE_SSL_FAILED Requested FTP SSL level failed.',
		66 => 'CURLE_SSL_ENGINE_INITFAILED Initiating the SSL Engine failed.',
		77 => 'CURLE_SSL_CACERT_BADFILE Problem with reading the SSL CA cert (path? access rights?)',
		78 => 'CURLE_REMOTE_FILE_NOT_FOUND The resource referenced in the URL does not exist.',
		80 => 'CURLE_SSL_SHUTDOWN_FAILED Failed to shut down the SSL connection.',
		82 => 'CURLE_SSL_CRL_BADFILE Failed to load CRL file.',
		83 => 'CURLE_SSL_ISSUER_ERROR Issuer check failed.',
		90 => 'CURLE_SSL_PINNEDPUBKEYNOTMATCH Failed to match the pinned key specified with '
			. 'CURLOPT_PINNEDPUBLICKEY.',
		91 => 'CURLE_SSL_INVALIDCERTSTATUS Status returned failure when asked with '
			. 'CURLOPT_SSL_VERIFYSTATUS . ',
	);
	my $curl_exit_value;
	my $curl_exit_text;
	if ( defined $url_format_object{curl_return} ) {
		$curl_exit_value = ${ $url_format_object{curl_return} };
		if ( defined $curl_exit_codes{$curl_exit_value} ) {
			$curl_exit_text = $curl_exit_codes{$curl_exit_value};
		}
		if ( ( defined $bad_ssl && !defined $url_format_object{title} )
			|| $curl_exit_value != 0 && $curl_exit_value != 23 && defined $curl_exit_value )
		{
			print_stderr("HELPPP");
			print_stderr($curl_exit_text);
			msg_same_origin( $who_said,
				"$url_format_object{url} . Curl error code: ${$url_format_object{curl_return}} $curl_exit_text" );
		}
	}

	print_stderr("CURL return $curl_exit_value");

	if ( $format_success != 1 || $url_format_object{title} =~ /^\s*$/ || !$url_format_object{is_text} ) {
		print_stderr("failed to format succes or title is blank or it's not text");
		return 0;
	}
	my $cloudflare_text  = $EMPTY;
	my $max_title_length = 120;
	if ( $url_format_object{is_cloudflare} ) {

		#text_style( ' bold ', '**CLOUDFLARE**' )
		$cloudflare_text = $SPACE . text_style( 'CLOUDFLARE ⛅', 'bold', 'orange' );
	}
	my $new_location_text;
	my $title_text;
	my $cookie_text  = $EMPTY;
	my $bad_ssl_text = $EMPTY;
	if ( $url_format_object{has_cookie} >= 1 ) {
		$cookie_text = $SPACE . text_style( '🍪', 'bold', 'brown' );
	}
	if ( $url_format_object{is_404} ) {
		print_stderr('find_url return, 404 error');
		return 0;
	}

	if ( $url_format_object{url} !~ m{twitter[.]com/.+/status} ) {
		$url_format_object{title} = shorten_text( $url_format_object{title}, $max_title_length );
	}

	if ( defined $url_format_object{new_location} ) {
		$new_location_text = ' >> ' . text_style( $url_format_object{new_location}, 'underline', 'blue' );
	}
	else {
		$new_location_text = $EMPTY;
	}
	if ( defined $bad_ssl ) {
		if ( $url_format_object{curl_return} eq '60' ) {
			$bad_ssl_text = $SPACE . text_style( 'BAD SSL CERT', 'bold', 'white', 'red' );
		}
	}
	$title_text = q([ ) . text_style( $url_format_object{title}, undef, 'teal' ) . q( ]);
	$title_text = text_style( $title_text, 'bold' );
	msg_same_origin( $who_said,
		$title_text . $new_location_text . $cookie_text . $cloudflare_text . $bad_ssl_text );

	return;
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
		print_stderr("There are $count_or instances of 'or'");
		if ( $count_or > 2 ) {
			msg_same_origin( $coin_who, q/I don't support asking more than three things at once... yet/ );
		}
		elsif ( $count_or == 2 ) {
			$thing_said =~ m/^\s*(.*)\s*\bor\b\s*(.*)\s*\bor\b\s*(.*)\s*$/;
			print_stderr("One: $1 Two: $2 Three: $3");
			if ( $coin_3 == 0 ) {
				$thing_said = rephrase($1);
				msg_same_origin( $coin_who, $thing_said );
			}
			elsif ( $coin_3 == 1 ) {
				$thing_said = rephrase($2);
				msg_same_origin( $coin_who, $thing_said );
			}
			elsif ( $coin_3 == 2 ) {
				$thing_said = rephrase($3);
				msg_same_origin( $coin_who, $thing_said ) and return 1;
			}
		}
		else {
			if ($coin) {
				$thing_said =~ s/\s*\bor\b.*//;
				$thing_said = rephrase($thing_said);
				msg_same_origin( $coin_who, $thing_said ) and return 1;
			}
			else {
				$thing_said =~ s/.*\bor\b\s*//;
				$thing_said = rephrase($thing_said);
				msg_same_origin( $coin_who, $thing_said ) and return 1;
			}
		}
	}
	else {
		if   ($coin) { msg_same_origin( $coin_who, "Yes: $thing_said" ) and return 1 }
		else         { msg_same_origin( $coin_who, "No: $thing_said" )  and return 1 }
	}
	return 0;
}

sub addressed {
	my ( $addressed_who, $addressed_said ) = @_;

	return 0;
}

sub trunicate_history {
	system "tail -n $history_file_length $history_file | sponge $history_file"
		and print_stderr("Problem with tail ./$history_file | sponge ./$history_file, Error $ERRNO");

	return;
}

sub username_defined_post {

	if ( -f $tell_file ) {
		print_stderr( localtime(time) . "\tCalling tell_nick" );
		my ($tell_to_say) = tell_nick($who_said);
		if ( defined $tell_to_say ) {
			print_stderr('Tell to say line next');
			msg_same_origin( $who_said, $tell_to_say );
			url_format_text( find_url($tell_to_say) );

		}
	}

	# Trunicate history file only if the bot's username is set.
	if ( -f $history_file ) {
		trunicate_history;
	}
	return;
}

sub sanitize {
	my ($dirty_string) = @_;
	$dirty_string =~ tr/\000-\032/ /;
	$dirty_string =~ s/$control_codes{DEL}//;
	$dirty_string =~ s/ +/ /g;
	return $dirty_string;
}

sub replace_newline {
	my ($multi_line_string) = @_;
	$multi_line_string =~ s/\r\n/ /g;
	$multi_line_string =~ s/\n/ /g;
	$multi_line_string =~ s/\r/ /g;
	return $multi_line_string;
}

sub to_symbols_newline {
	my ($multi_line_string) = @_;
	$multi_line_string =~ s/\n/␤/g;
	$multi_line_string =~ s/\r/↵/g;
	$multi_line_string =~ s/\t/↹/g;

	return $multi_line_string;
}

sub to_symbols_ctrl {
	my ($multi_line_string) = @_;

	foreach my $ascii ( keys %control_codes ) {
		if ( $ascii eq 'NULL' ) {
			$multi_line_string =~ s/$control_codes{$ascii}/\\0/g;
		}
		elsif ( $ascii eq 'DEL' ) {
			$multi_line_string =~ s/$control_codes{$ascii}/\\DEL/g;
		}
		else {
			$multi_line_string =~ s/$control_codes{$ascii}/^$ascii/g;
		}
	}

	my $ctrl_lb = chr 27;
	my $ctrl_bs = chr 28;
	my $ctrl_rb = chr 29;
	my $ctrl_ca = chr 30;
	my $ctrl_us = chr 31;

	#my $ctrl_qm = chr 127;
	$multi_line_string =~ s/$ctrl_lb/^[/g;
	$multi_line_string =~ s/$ctrl_bs/^\\/g;
	$multi_line_string =~ s/$ctrl_rb/^]/g;
	$multi_line_string =~ s/$ctrl_ca/^^/g;
	$multi_line_string =~ s/$ctrl_us/^_/g;

	# $multi_line_string =~ s/$ctrl_qm/^?/g;

	return $multi_line_string;
}

sub strip_cmd {
	my ($strip_said) = @_;
	$strip_said =~ s/^!\S* //;
	return $strip_said;

}

sub eval_perl {
	my ( $eval_who, $perl_command ) = @_;
	my $perl_all_out;
	my @perl_args = ( 'eval.pl', $perl_command );
	my ( $perl_stdin_fh, $perl_stdout_fh, $perl_stderr_fh );
	$perl_stderr_fh = gensym;
	my $pid = open3( $perl_stdin_fh, $perl_stdout_fh, $perl_stderr_fh, 'perl', @perl_args )
		or print_stderr("Could not open eval.pl, Error $ERRNO");
	my $perl_stdout = do { local $INPUT_RECORD_SEPARATOR; <$perl_stdout_fh> };
	my $perl_stderr = do { local $INPUT_RECORD_SEPARATOR; <$perl_stderr_fh> };

	waitpid $pid, 0;
	if ( defined $perl_stdout_fh ) {
		close $perl_stdout_fh or print_stderr("Could not close eval.pl, Error $ERRNO");
	}
	if ( defined $perl_stdout_fh ) {
		close $perl_stderr_fh or print_stderr("Could not close eval.pl, Error $ERRNO");
	}

	if ( defined $perl_stdout ) {

		$perl_all_out = 'STDOUT: «' . $perl_stdout . '» ';
	}
	if ( defined $perl_stderr ) {

		#$perl_stderr = try_decode($perl_stderr);
		$perl_stderr =~ s/isn't numeric in numeric ne .*?eval[.]pl line \d+[.]//g;
		$perl_all_out .= 'STDERR: «' . $perl_stderr . q(»);
	}
	if ( defined $perl_all_out ) {
		$perl_all_out = to_symbols_newline($perl_all_out);
		$perl_all_out = to_symbols_ctrl($perl_all_out);

		$perl_all_out = shorten_text( $perl_all_out, 260 );

		msg_same_origin( $eval_who, $perl_all_out ) and return 1;
	}
	return 0;
}

sub codepoint_to_unicode {
	my ( $codepoint_who, $unicode_code, $force ) = @_;
	my $null_byte_msg = 'Null bytes are prohibited on IRC by RFC1459. If you are a terrible '
		. 'person and want to break the spec, use !UNICODE';
	$unicode_code =~ s/\[u[+](\S+)\]/$1/g;
	if ( $unicode_code =~ /\b0+\b/ && !$force ) {
		msg_same_origin( $codepoint_who, $null_byte_msg ) and return 1;
	}
	else {
		my @unicode_array = split $SPACE, $unicode_code;
		my $unicode_code2;
		foreach my $u_line (@unicode_array) {
			$unicode_code2 .= chr hex $u_line;
		}

		$unicode_code2 = to_symbols_newline($unicode_code2);

		msg_same_origin( $codepoint_who, $unicode_code2 ) and return 1;
	}
	return 0;
}

sub codepoint_to_unicode_force {
	my @__ = @_;
	codepoint_to_unicode( @__, 1 ) and return 1;
	return 0;
}

sub urban_dictionary {
	my ( $ud_who, $ud_request ) = @_;
	my @ud_args = ( 'ud.pl', $ud_request );
	my $ud_pid = open( my $UD_OUT, '-|', 'perl', @ud_args )
		or print_stderr("Could not open UD pipe, Error $ERRNO");
	my ( $definition, $example );
	my $ud_line = do { local $INPUT_RECORD_SEPARATOR; <$UD_OUT> };
	if ( $ud_line =~ m{%DEF%(.*)%EXA%(.*)} ) {
		$definition = $1;
		$example    = $2;
	}

	if ( !defined $definition ) {
		return;
	}
	$definition = sanitize($definition);
	$definition = shorten_text($definition);

	$example = sanitize($example);
	$example = shorten_text($example);
	$example = text_style( $example, 'italic' );

	$ud_request = ucfirst $ud_request;
	$ud_request = text_style( $ud_request, 'bold' );
	my $ud_one_line = "$ud_request: $definition $example";

	#print_stderr(length $definition);
	if ( length $ud_one_line > 300 ) {
		my $ud_two_lines = "$ud_request: $definition\n" . q(%) . $example;
		msg_same_origin( $ud_who, $ud_two_lines ) and return 1;

	}
	else {
		msg_same_origin( $ud_who, $ud_one_line ) and return 1;
	}
	return 0;
}

sub get_codepoints {
	my ( $code_who, $to_unpack ) = @_;

	my @codepoints = unpack 'U*', $to_unpack;

	my $str = sprintf '%x ' x @codepoints, @codepoints;
	$str =~ s/ $//;
	$str = uc $str;
	msg_same_origin( $code_who, $str ) and return 1;
	return 0;
}

# MAIN
if ( defined $bot_username and $bot_username ne $EMPTY ) {
	username_defined_pre;

}

# .bots reporting functionality
if ( $body =~ /[.]bots.*/ ) {
	msg_same_origin( $who_said, "$bot_username reporting in! [perl] $repo_url v$VERSION" );
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
if ( $body =~ m{^s/.+/}i and defined $history_file and $bot_username ne 'skbot' ) {
	my ( $sed_who, $sed_text ) = sed_replace($body);
	$sed_text = shorten_text($sed_text);

	if ( defined $sed_who and defined $sed_text ) {
		print_stderr("sed_who: $sed_who sed_text: $sed_text");
		msg_channel("<$sed_who> $sed_text");
	}
}

sub get_cmd {
	my ($get_cmd) = @_;
	$get_cmd =~ s/^!(\S*)\b.*/$1/;
	return $get_cmd;
}

sub make_fullwidth {
	my ( $fw_who, $fw_text ) = @_;
	my $fullwidth = to_fullwidth($fw_text);

	# Match $style_table{color} aka ^C codes and convert the numbers back if they're part of a color code
	$fullwidth =~ s/(\N{U+03}\d?\d?\N{U+FF0C}?\d?\d?)/$1 =~  tr{\N{U+FF10}-\N{U+FF19}\N{U+FF0C}}{0-9,}r/e;

	msg_same_origin( $fw_who, $fullwidth ) and return 1;
	return 0;
}

sub print_help {
	my ( $help_who, $help_body ) = @_;
	private_message( $help_who, $help_text ) and return 1;
	return 0;
}

my %commands = (
	transliterate => \&transliterate,
	tell          => \&tell_nick_command,
	fullwidth     => \&make_fullwidth,
	fw            => \&make_fullwidth,
	fromhex       => \&from_hex,
	tohex         => \&to_hex,
	u             => \&get_codepoints,
	uc            => \&uppercase,
	ucirc         => \&uppercase_irc,
	lc            => \&lowercase,
	lcirc         => \&lowercase_irc,
	perl          => \&eval_perl,
	p             => \&eval_perl,
	ud            => \&urban_dictionary,
	help          => \&print_help,
	unicode       => \&codepoint_to_unicode,
	UNICODE       => \&codepoint_to_unicode_force,
	action        => \&format_action,
);
if ( $body =~ /^!/ && defined $commands{ get_cmd($body) } ) {
	$commands{ get_cmd $body }( $who_said, strip_cmd $body );
}
else {
	# Find and get URL's page title
	url_format_text( find_url($body) );
}

