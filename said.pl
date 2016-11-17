#!/usr/bin/env perl
# said perlbot script
$| = 1;
use 5.012;
use strict;
use warnings;
use Encode;
use Symbol 'gensym';
use Encode::Detect;
use feature 'unicode_strings';
use utf8 qw(decode);
use English;
use Time::Seconds qw(ONE_MINUTE ONE_HOUR ONE_DAY ONE_YEAR);
use Convert::EastAsianWidth qw(to_fullwidth);
use Text::Unidecode qw(unidecode);
use lib qw(./);
use lib::TextStyle qw(text_style style_table);
use lib::TryDecode qw(try_decode);

binmode STDOUT, ':encoding(UTF-8)'
	or print_stderr("Failed to set binmode on STDOUT, Error $ERRNO");
binmode STDERR, ':encoding(UTF-8)'
	or print_stderr("Failed to set binmode on STDERR, Error $ERRNO");

our $VERSION = 0.9;
my $repo_url = 'https://github.com/samcv/keira-perl6-ircbot';
my $repo_formatted = text_style( $repo_url, 'underline', 'blue' );

my ( $history_file, $channel_event_file );
my $history_file_length = 30;

my $EMPTY = q{};
my $SPACE = q{ };

my %ctrl_codes = (
	'NULL' => chr 0,
	'A'    => chr 1,
	'B'    => chr 2,
	'C'    => chr 3,
	'D'    => chr 4,
	'E'    => chr 5,
	'F'    => chr 6,
	'G'    => chr 7,
	'H'    => chr 8,
	'I'    => chr 9,
	'J'    => chr 10,
	'K'    => chr 11,
	'L'    => chr 12,
	'M'    => chr 13,
	'N'    => chr 14,
	'O'    => chr 15,
	'P'    => chr 16,
	'Q'    => chr 17,
	'R'    => chr 18,
	'S'    => chr 19,
	'T'    => chr 20,
	'U'    => chr 21,
	'V'    => chr 22,
	'W'    => chr 23,
	'X'    => chr 24,
	'Y'    => chr 25,
	'Z'    => chr 26,
	'ESC'  => chr 27,
	'DEL'  => chr 127,
);

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
	my ( $so_msg_who, $so_msg_text, $channel ) = @_;
	if ( !defined $so_msg_text || $so_msg_text eq $EMPTY ) {
		print_stderr('Not defined or empty message in msg_same_origin');
		return 0;
	}
	if ( defined $channel ) {
		if ( $channel eq 'msg' ) {
			private_message( $so_msg_who, $so_msg_text ) and return 1;
		}
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
	my ( $who_said, $body, $channel, $bot_username ) = @_;
	utf8::decode($bot_username);

	return;
}

sub format_action {
	my ( $action_who, $action_text ) = @_;
	$action_text = "\cA" . 'ACTION' . $SPACE . $action_text . "\cA";
	msg_same_origin( $action_who, $action_text ) and return 1;
	return 0;
}

sub lowercase_irc {
	my ( $lc_irc_who, $lc_irc_said ) = @_;

	# IRC defines {}\ as the uppercase form of []| respectively
	$lc_irc_said =~ tr/\[\]\\/{}|/;
	msg_same_origin( $lc_irc_who, lc $lc_irc_said ) and return 1;
	return 0;
}

sub uppercase_irc {
	my ( $uc_irc_who, $uc_irc_said ) = @_;
	$uc_irc_said =~ tr/{}|/\[\]\\/;
	msg_same_origin( $uc_irc_who, uc $uc_irc_said ) and return 1;
	return 0;
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

sub transliterate {
	my ( $transliterate_who, $transliterate_said ) = @_;
	my $transliterate_return = unidecode($transliterate_said);
	msg_same_origin( $transliterate_who, $transliterate_return ) and return 1;

	return 0;
}

sub find_url {
	my ($find_url_caller_text) = @_;
	my ( $find_url_url, $new_location_text );
	my $max_title_length = 120;
	my $error_line       = 0;
	if (   $find_url_caller_text !~ m{https?://}
		or $find_url_caller_text =~ m{\#\#\s*http.?://} )
	{
		return 0;
	}
	require lib::LocateURLs;

	my @find_url_array = locate_urls($find_url_caller_text);

	foreach my $single_url (@find_url_array) {

		# Make sure we don't use FTP
		if ( $single_url !~ m{^ftp://}i ) {
			$find_url_url = $single_url;
			print_stderr("Found $find_url_url as the first url");
			last;
		}
	}

	if ( defined $find_url_url ) {
		require lib::CurlTitle;

		my %url_object = %{ get_url_title_new($find_url_url) };

		my $return_code  = $url_object{curl_return};
		my $return_tries = 0;
		my $url_new_location;
		print_stderr("RETURN CODE IS $return_code");

		return ( 1, \%url_object );

	}
	else {
		return 0;
	}
}

sub url_format_text {
	my ( $format_success, $ref, $who_said, $body, $channel, $bot_username ) = @_;
	my $real_title = 0;
	if ( !defined $ref ) {

		#print_stderr('$ref is not defined!!!');
		return 0;
	}
	my %url_object = %{$ref};
	if ( defined $url_object{'title'} ) {
		if ( $url_object{'title'} =~ /^\s*$/ ) {
			print_stderr('URL title is blank');
		}
		else {
			$real_title = 1;
		}
	}
	else {
		print_stderr('URL title is not defined');
	}
	if ( !$url_object{'is_text'} ) {
		print_stderr("Curl response isn't text");
	}
	my $curl_exit_text;
	my $curl_exit_value = $url_object{curl_return};
	if ( defined curl_exit_codes($curl_exit_value) ) {
		$curl_exit_text = curl_exit_codes($curl_exit_value);
	}
	if ( !defined $curl_exit_value ) {
		return 0;
	}
	my $curl_think_error = 0;
	if ( $curl_exit_value != 0 and $curl_exit_value != 23 ) {
		$curl_think_error = 1;
		print_stderr("Curl exit value is $curl_exit_value this is an error");
	}
	if ($curl_think_error) {
		msg_same_origin( $who_said,
			"$url_object{url} . Curl error code: $curl_exit_value $curl_exit_text" );
	}
	if ( !$real_title ) {
		print_stderr("No title, so not printing any title");
		return 0;
	}

	print_stderr("CURL return $curl_exit_value");

	my $cloudflare_text   = $EMPTY;
	my $cookie_text       = $EMPTY;
	my $bad_ssl_text      = $EMPTY;
	my $new_location_text = $EMPTY;
	my $title_text;
	my $max_title_length = 120;
	my $twitter_re       = 'twitter[.]com/.+/status';

	# Title
	if ( $url_object{url} =~ m{$twitter_re} ) {
		print_stderr('match');
		my $tweet_title = $url_object{title};
		$tweet_title =~ s{(https?://\S+)(")}{$1 $2}g;
		print_stderr $tweet_title;
		$url_object{title} = $tweet_title;
	}
	$title_text = q([ ) . text_style( $url_object{title}, undef, 'teal' ) . q( ]);
	$title_text = text_style( $title_text, 'bold' );
	if (    $url_object{url} !~ m{twitter[.]com/.+/status}
		and $url_object{url} !~ m{reddit[.]com/} )
	{
		$url_object{title}
			= shorten_text( $url_object{title}, $max_title_length );
	}

	# New Location
	if ( defined $url_object{new_location} ) {
		$new_location_text = ' >> ' . text_style( $url_object{new_location}, 'underline', 'blue' ) . $SPACE;
	}

	# Cookie
	if ( $url_object{has_cookie} >= 1 ) {
		$cookie_text = text_style( '🍪  ', 'bold', 'brown' );
	}

	# Cloudflare
	if ( $url_object{is_cloudflare} ) {
		$cloudflare_text = text_style( 'Cloudflare ⛅ ', 'bold', 'orange' );
	}

	# 404
	if ( $url_object{is_404} ) {
		print_stderr('find_url return, 404 error');
		return 0;
	}

	# Bad SSL
	if ( $url_object{bad_ssl} ) {
		$bad_ssl_text = text_style( 'BAD SSL', 'bold', 'white', 'red' );
	}

	msg_same_origin( $who_said,
		$title_text . $new_location_text . $cookie_text . $cloudflare_text . $bad_ssl_text )
		and return 1;

	return 0;
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
	my ( $coin_who, $coin_said, $channel, $bot_username ) = @_;
	my $coin       = int rand 2;
	my $coin_3     = int rand 3;
	my $thing_said = $coin_said;
	$thing_said =~ s/^\Q$bot_username\E\S?\s*//;
	$thing_said =~ s/[?]//g;

	if ( $coin_said =~ /\bor\b/ ) {
		my $count_or;
		my $word = 'or';
		while ( $coin_said =~ /\b$word\b/g ) {
			++$count_or;
		}
		print_stderr("There are $count_or instances of 'or'");
		if ( $count_or > 2 ) {
			msg_same_origin( $coin_who, "I don't support asking more than three things at once... yet" );
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
		$thing_said = ucfirst $thing_said;
		if ($coin) {
			msg_same_origin( $coin_who, "$thing_said? Yes." ) and return 1;
		}
		else { msg_same_origin( $coin_who, "$thing_said? No." ) and return 1 }
	}
	return 0;
}

sub addressed {
	my ( $addressed_who, $addressed_said ) = @_;

	return 0;
}

sub username_defined_post {
	my ( $who_said, $body, $channel, $bot_username ) = @_;

	# Trunicate history file only if the bot's username is set.
	return;
}

sub sanitize {
	my ($dirty_string) = @_;

	# Chars from 0 to 32 are control codes. Remove all except
	# newlines and carriage returns
	$dirty_string
		=~ s/[$ctrl_codes{NULL}-$ctrl_codes{I}$ctrl_codes{K}$ctrl_codes{L}$ctrl_codes{N}-$ctrl_codes{ESC}]//g;

	#$dirty_string =~ s/[$ctrl_codes{K}-$ctrl_codes{L}]//g;

	$dirty_string =~ s/$ctrl_codes{DEL}//g;

	#$dirty_string =~ s/$ctrl_codes{ESC}//g;
	#$dirty_string =~ s/ +/ /g;
	return $dirty_string;
}

sub replace_newline {
	my ($multi_line_string) = @_;
	$multi_line_string =~ s/\r\n/ /g;
	$multi_line_string =~ s/\n/ /g;
	$multi_line_string =~ s/\r/ /g;
	$multi_line_string =~ s/ +/ /g;
	return $multi_line_string;
}

sub get_fortune {
	my ( $fortune_who, $fortune_caller_text ) = @_;
	my $fortune;
	my $fortune_max = 350;
	print_stderr("Fortune caller_text: $fortune_caller_text");
	my $fortune_cmd = "fortune -n $fortune_max";

	my $fortune_fh;
	if ( !open $fortune_fh, q(-|), "$fortune_cmd" ) {
		print_stderr( 'Could not open $fortune_fh, Error ' . "$ERRNO" );
		return 0;
	}
	$fortune = do { local $INPUT_RECORD_SEPARATOR = undef; <$fortune_fh> };

	close $fortune_fh
		or print_stderr("Could not close fortune_fh, Error $ERRNO");

	$fortune = try_decode($fortune);
	chomp $fortune;
	$fortune = sanitize($fortune);
	$fortune = replace_newline($fortune);

	$fortune = shorten_text( $fortune, 500 );

	# If the fortune isn't empty, return it
	if ( $fortune !~ /^\s*$/ ) {
		msg_same_origin( $fortune_who, $fortune ) and return 1;
	}
	else {
		print_stderr('Fortune empty!');
	}

	return 0;
}

sub u_lookup {
	my ( $u_lookup_who, $u_lookup_code ) = @_;
	if ( $u_lookup_code =~ m/^(\S+)/ ) {
		$u_lookup_code = $1;
		my $url = 'https://www.fileformat.info/info/unicode/char/' . $u_lookup_code . '/index.htm';
		msg_same_origin( $u_lookup_who, $url ) and return 1;
	}
	return 0;
}

sub unicode_lookup {
	my ( $u_lookup_who, $u_lookup_code, $channel, $bot_username ) = @_;
	if ( $u_lookup_code =~ m/^(\S+)/ ) {
		$u_lookup_code = $1;
		my @codepoints = unpack 'U*', $u_lookup_code;
		my $str = sprintf '%x ' x @codepoints, @codepoints;
		$str =~ s/\s*(.*\S)\s*/$1/;
		my $url = "https://www.fileformat.info/info/unicode/char/$str/index.htm";
		msg_same_origin( $u_lookup_who, $url );
		url_format_text( find_url($url), $u_lookup_who, $u_lookup_code, $channel, $bot_username );
	}
	return 0;
}

sub make_fullwidth {
	my ( $fw_who, $fw_text ) = @_;
	my $fullwidth = to_fullwidth($fw_text);

	# Match style_table('color') aka ^C codes and convert the numbers
	# back if they're part of a color code
	$fullwidth =~ s/(\N{U+03}\d?\d?\N{U+FF0C}?\d?\d?)/$1
		=~ tr{\N{U+FF10}-\N{U+FF19}\N{U+FF0C}}{0-9,}r/e;

	msg_same_origin( $fw_who, $fullwidth ) and return 1;
	return 0;
}

sub get_cmd {
	my ($get_cmd) = @_;
	my $strip_cmd = $EMPTY;
	my $cmd       = $EMPTY;
	if ( $get_cmd =~ m/^!(\S*)/ ) {
		$cmd = $1;
	}
	if ( $get_cmd =~ m/^!\S* (.*)/ ) {
		$strip_cmd = $1;
	}
	return $cmd, $strip_cmd;
}
my %commands = (
	'transliterate' => \&transliterate,
	'fullwidth'     => \&make_fullwidth,
	'fw'            => \&make_fullwidth,
	'unicodelookup' => \&u_lookup,
	'ul'            => \&unicode_lookup,
	'ucirc'         => \&uppercase_irc,
	'lcirc'         => \&lowercase_irc,
	'action'        => \&format_action,
);
print_stderr("starting format #channel >botusername< <who> message");

while (<>) {
	if ( !m{(\S+?) >(\S+?)< <(\S+?)> (.*)} ) {
		if (m{^KILL}) {
			exit;
		}
		print_stderr("Line did not match, you will have lots of errors after this!");
	}
	my $channel      = $1;
	my $bot_username = $2;

	#print $bot_username . "\n";
	my $who_said     = $3;
	my $body         = $4;
	my $welcome_text = "Welcome to the channel $who_said. We're friendly here, "
		. 'read the topic and please be patient.';
	utf8::decode($who_said);
	utf8::decode($body);
	if ( defined $channel ) { utf8::decode($channel) }

	# MAIN
	if ( defined $bot_username and $bot_username ne $EMPTY ) {
		username_defined_pre( $who_said, $body, $channel, $bot_username );
	}

	# .bots reporting functionality
	if ( $body =~ /[.]bots.*/ ) {
		msg_same_origin( $who_said, "$bot_username reporting in! [Perl 5+6] $repo_url v$VERSION" );
	}

	# If the bot is addressed by name, call this function
	if ( $body =~ /$bot_username/ ) {
		if ( $body =~ /[?]/ ) {
			bot_coin( $who_said, $body, $channel, $bot_username );
		}
		else {
			addressed( $who_said, $body );
		}
	}
	if ( $body =~ /^!/ ) {
		my ( $get_cmd, $strip_cmd ) = get_cmd($body);
		if ( defined $commands{$get_cmd} ) {
			print_stderr("who: $who_said cmd: $strip_cmd");
			$commands{$get_cmd}( $who_said, $strip_cmd, $channel, $bot_username );
		}
	}

	# Find and get URL's page title
	my ( $one, $two ) = find_url($body);
	url_format_text( $one, $two, $who_said, $body, $channel, $bot_username );

	if ( $body =~ /\s:[(]\s*$/ or $body =~ /^\s*:[(]\s*$/ ) {
		my @cheer = ( q/Turn that frown upside down :)/, q/Cheer up! Don't be so sad!/ );
		my $cheer_text = $cheer[ rand @cheer ];
		msg_same_origin( $who_said, "$who_said, $cheer_text" );
	}

	if ( defined $bot_username and $bot_username ne $EMPTY ) {
		username_defined_post( $who_said, $body, $channel, $bot_username );
	}
}

# vim: noet
