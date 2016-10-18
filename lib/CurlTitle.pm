#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use feature 'unicode_strings';
use English;
use HTML::Entities 'decode_entities';
use lib::TryDecode qw(try_decode);
use Exporter qw(import);
our @EXPORT_OK = qw(text_style);

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

	while ( defined( my $curl_line = <$CURL_OUT> ) ) {

		# Processing done only within the header
		if ( $process{end_of_header} == 0 and defined $curl_line ) {

			# Detect end of header
			if ( $curl_line =~ /^\s*$/ ) {
				$process{end_of_header} = 1;
				if ( $process{is_text} == 0 or defined $process{new_location} ) {
					print {*STDERR} q/Stopping because it's not text or a new location is defined/;
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
					print {*STDERR} "Line $process{line_no} is '$curl_line'";
				}
			}

			# If we reach the </head>, <body> have reached the end of title
			if ( $curl_line =~ m{</head>} or $curl_line =~ m{<body.*?>} or $process{title_end_line} != 0 ) {
				last;
			}
		}

		$process{line_no}++;
	}

	if (@curl_title) { $process{curl_title} = \@curl_title }
	my $return = \%process;
	return \%process;
}

sub get_url_title_new {
	my ( $sub_url, $curl_unsafe_ssl, $max_redirects ) = @_;
	if ( !defined $max_redirects ) { $max_redirects = 3 }

	my %url_object = %{ get_url_title($sub_url) };
	my $url_new_location;
	my $redirects = 0;
	while ( defined $url_object{new_location} and $redirects < $max_redirects ) {

		# If the location starts with a / then it is a reference to a url on the same domain
		if ( $url_object{new_location} =~ m{^/} ) {
			print_stderr('Matched a / in the url new location start');
			my $temp6 = $url_object{url};
			$temp6 =~ s{(https?://\S*?)/.*}{$1};
			$url_object{new_location} = $temp6 . $url_object{new_location};
		}
		$redirects++;
		if ( defined $url_object{new_location} ) {
			$url_new_location = $url_object{new_location};
			%url_object       = %{ get_url_title($url_new_location) };
		}
	}
	my $return_code  = $url_object{curl_return};
	my $return_tries = 0;
	my $bad_ssl;
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
		print_stderr("RETURN CODE MATCH FOR BAD SSL LOOP");
		while ( defined $url_object{curl_return} and $return_tries < 2 ) {
			$bad_ssl = 'BAD_SSL';
			if ( $url_object{curl_return} == 0 or $url_object{curl_return} == 23 ) {last}
			if ( defined $url_new_location ) {
				%url_object = %{ get_url_title( $url_new_location, 'UNSAFE_SSL' ) };
			}
			else {
				print_stderr("getting bad ssl page");
				%url_object = %{ get_url_title( $sub_url, 'UNSAFE_SSL' ) };
			}
			$return_tries++;
		}
	}
	if ($return_tries) {
		$url_object{curl_return} = \$return_code;
	}
	$url_object{new_location} = $url_new_location;
	return \%url_object;
}

sub get_url_title {
	my ( $sub_url, $curl_unsafe_ssl ) = @_;
	print {*STDERR} qq/Curl Location: "$sub_url"/;

	my $user_agent
		= 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) '
		. 'AppleWebKit/537.36 (KHTML, like Gecko) '
		. 'Chrome/53.0.2785.116 Safari/537.36';
	my @curl_unsafe_ssl_flags = ('-k');

	if ( !defined $curl_unsafe_ssl ) {
		$curl_unsafe_ssl = 'NO';
	}

	my $curl_max_time    = 5;
	my $curl_retry_times = 1;
	my @curl_args;
	@curl_args = (
		'--compressed', '-H',          $user_agent, '--retry', $curl_retry_times, '--max-time',
		$curl_max_time, '--no-buffer', '-i',        '--url',   $sub_url,
	);
	if ( $curl_unsafe_ssl eq 'UNSAFE_SSL' ) {
		print {*STDERR} "UNSAFE Setting curl unsafe-ssl to $curl_unsafe_ssl";
		unshift @curl_args, @curl_unsafe_ssl_flags;
	}

	my ( $CURL_STDERR, $CURL_STDIN, $CURL_OUT );

	# If we don't set this sometimes weird things happen and filehandles could get combined
	# Using open3
	#$CURL_STDERR = gensym;

	# Don't set BINMODE on curl's output because we will decode later on
	#my $curl_pid = open3( $CURL_STDIN, $CURL_OUT, $CURL_STDERR, 'curl', @curl_args )
	my $curl_pid = open $CURL_OUT, '-|', 'curl', @curl_args
		or print {*STDERR} "Could not open curl pipe, Error $ERRNO";

	# Processing on the stream is done here
	my %new_object = %{ process_curl( $curl_pid, $CURL_OUT, $CURL_STDERR ) };

	for ( $CURL_OUT, $CURL_STDIN, $CURL_STDERR ) {
		if (defined) {
			close $_ or print {*STDERR} "Could not close curl pipe";
			if ( !defined $new_object{curl_return} ) {
				$new_object{curl_return} = $CHILD_ERROR >> 8;
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

	if ( !defined $new_object{new_location} && defined $new_object{curl_title} ) {
		my $title = join q(  ), @{ $new_object{curl_title} };
		$title = try_decode($title);

		# Decode html entities such as &nbsp
		$title = decode_entities($title);

		# Replace carriage returns with two spaces
		$title =~ s/\r/  /g;

		print_stderr(qq(Title is: "$title"));
		$new_object{title} = $title;

	}
	$new_object{url} = $sub_url;

	#$new_object{title} = $title;
	$curl_return = $new_object{curl_return};
	print_stderr("$curl_return");
	$new_object{curl_return} = \$curl_return;

	return \%new_object;
}
