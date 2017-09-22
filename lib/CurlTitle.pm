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
	my $title_start_regex1 = '.*<title>';
	my $title_end_regex   = '</title>.*';
	my @curl_title;

	while ( defined( my $curl_line = <$CURL_OUT> ) ) {

		# Processing done only within the header
		if ( $process{end_of_header} == 0 and defined $curl_line ) {

			# Detect end of header
			if ( $curl_line =~ /^\s*$/ ) {
				$process{end_of_header} = 1;
				if ( $process{is_text} == 0 or defined $process{new_location} ) {
					print {*STDERR}
						q/Stopping because it's not text or a new location is defined/;
					last;
				}
			}

			# Detect content type
			elsif ( $curl_line =~ /^Content-Type:/i ) {
				if ( $curl_line =~ /text/i ) {
					$process{'is_text'} = 1;
				}
				if ( $curl_line =~ m/charset=(\S+)/ ) {
					$process{'encoding'} = $1;
				}
			}
			elsif ( $curl_line =~ /^CF-RAY:/i ) { $process{is_cloudflare} = 1 }
			elsif ( $curl_line =~ /^Set-Cookie.*/i ) { $process{has_cookie}++ }
			elsif ( $curl_line =~ s/^Location:\s*(\S*)\s*$/$1/i ) {
				$process{new_location} = $curl_line;
			}
		}

		# Processing done after the header
		elsif ( defined $curl_line ) {

			# Find the <title> element
			if ( $curl_line =~ s{$title_start_regex1}{}i || $curl_line =~ s{$title_start_regex}{}i ) {
				print ">>>>> $curl_line\n";
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
					print {*STDERR} "Line $process{line_no} is '$curl_line'\n";
				}
			}

			# If we reach the </head>, <body> have reached the end of title
			if (   $curl_line =~ m{</head>}
				or $curl_line =~ m{<body.*?>}
				or $process{title_end_line} != 0 )
			{
				last;
			}
		}

		$process{line_no}++;
	}

	if (@curl_title) { $process{curl_title} = \@curl_title }

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
			print {*STDERR} "Matched a / in the url new location start\n";
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
	my $return_code = $url_object{curl_return};
	print {*STDERR} "IN NEW SECTION CURL ERROR IS $return_code\n";

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
		print {*STDERR} "RETURN CODE MATCH FOR BAD SSL LOOP\n";
		while ( defined $url_object{curl_return} and $return_tries < 2 ) {
			$bad_ssl = 'BAD_SSL';
			if ( $url_object{curl_return} == 0 or $url_object{curl_return} == 23 ) {last}
			if ( defined $url_new_location ) {
				%url_object = %{ get_url_title( $url_new_location, 'UNSAFE_SSL' ) };
			}
			else {
				print {*STDERR} "getting bad ssl page";
				%url_object = %{ get_url_title( $sub_url, 'UNSAFE_SSL' ) };
			}
			$return_tries++;
		}
		if ( defined $bad_ssl ) {
			$url_object{bad_ssl} = 1;
		}
		else {
			$url_object{bad_ssl} = 0;
		}
	}
	if ($return_tries) {
		$url_object{curl_return} = $return_code;
	}
	$url_object{new_location} = $url_new_location;
	return \%url_object;
}

sub get_url_title {
	my ( $sub_url, $curl_unsafe_ssl ) = @_;
	print {*STDERR} qq/Curl Location: "$sub_url"\n/;

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
		'--compressed',    '-H',         $user_agent,    '--retry',
		$curl_retry_times, '--max-time', $curl_max_time, '--no-buffer',
		'-i',              '--url',      $sub_url,
	);
	if ( $curl_unsafe_ssl eq 'UNSAFE_SSL' ) {
		print {*STDERR} "UNSAFE Setting curl unsafe-ssl to $curl_unsafe_ssl\n";
		unshift @curl_args, @curl_unsafe_ssl_flags;
	}

	my ( $CURL_STDERR, $CURL_STDIN, $CURL_OUT );

# If we don't set this sometimes weird things happen and filehandles could get combined
# Using open3
#$CURL_STDERR = gensym;

 # Don't set BINMODE on curl's output because we will decode later on
 #my $curl_pid = open3( $CURL_STDIN, $CURL_OUT, $CURL_STDERR, 'curl', @curl_args )
	my $curl_pid = open $CURL_OUT, '-|', 'curl', @curl_args
		or print {*STDERR} "Could not open curl pipe, Error $ERRNO\n";

	# Processing on the stream is done here
	my %new_object = %{ process_curl( $curl_pid, $CURL_OUT, $CURL_STDERR ) };

	for ( $CURL_OUT, $CURL_STDIN, $CURL_STDERR ) {
		if (defined) {
			close $_ or print {*STDERR} "Could not close curl pipe\n";
			if ( !defined $new_object{curl_return} ) {
				$new_object{curl_return} = $CHILD_ERROR >> 8;
			}
		}
	}

	my $curl_return = $new_object{curl_return};
	print {*STDERR} "Curl return is $curl_return\n";
	if ( $curl_return == 0 ) {

		# Print out $process{is_text} and $title's values
		print {*STDERR} "Ended on line $new_object{line_no}  "
			. 'Is Text: '
			. "$new_object{is_text}  "
			. 'End of Header: '
			. "$new_object{end_of_header}\n";

		my $title_length
			= $new_object{title_end_line} - $new_object{title_start_line};
		print {*STDERR} 'Title Start Line: '
			. "$new_object{title_start_line}  "
			. 'Title End Line = '
			. $new_object{title_end_line}
			. " Lines from title start to end: $title_length\n";
	}
	else {
		print {*STDERR}
			"There was a problem with curl.  Error code $new_object{curl_return}\n";

	}

	if ( !defined $new_object{new_location} && defined $new_object{curl_title} ) {
		my $title = join q(  ), @{ $new_object{curl_title} };
		$title = try_decode( $title, $new_object{'encoding'} );

		# Decode html entities such as &nbsp
		$title = decode_entities($title);

		# Replace carriage returns with two spaces
		$title =~ s/\r/  /g;

		print {*STDERR} qq(Title is: ｢$title｣\n);
		$new_object{title} = $title;

	}
	$new_object{url} = $sub_url;

	$curl_return = $new_object{curl_return};
	print {*STDERR} "$curl_return\n";

	return \%new_object;
}

sub curl_exit_codes {
	my ($exit_code) = @_;
	my %curl_exit_codes = (
		1 =>
			"CURLE_UNSUPPORTED_PROTOCOL The URL you passed to libcurl used a protocol that this "
			. "libcurl does not support. The support might be a compile-time option that you "
			. "didn't use, it can be a misspelled protocol string or just a protocol libcurl "
			. "has no code for.",
		2 =>
			'CURLE_FAILED_INIT Very early initialization code failed. This is likely to be an '
			. 'internal error or problem, or a resource problem where something fundamental '
			. "couldn't get done at init time.",
		3 => 'CURLE_URL_MALFORMAT The URL was not properly formatted.',
		4 =>
			'CURLE_NOT_BUILT_IN A requested feature, protocol or option was not found built-in '
			. 'in this libcurl due to a build-time decision. This means that a feature or option '
			. 'was not enabled or explicitly disabled when libcurl was built and in order to '
			. 'get it to function you have to get a rebuilt libcurl.',
		5 =>
			"CURLE_COULDNT_RESOLVE_PROXY Couldn't resolve proxy. The given proxy host could "
			. 'not be resolved.',
		6 =>
			"CURLE_COULDNT_RESOLVE_HOST Couldn't resolve host. The given remote host was not resolved.",
		7 => 'CURLE_COULDNT_CONNECT Failed to connect() to host or proxy.',
		8 =>
			"CURLE_FTP_WEIRD_SERVER_REPLY The server sent data libcurl couldn't parse. This "
			. 'error code is used for more than just FTP',
		9 =>
			'CURLE_REMOTE_ACCESS_DENIED We were denied access to the resource given in the URL. '
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
		23 =>
			"CURLE_WRITE_ERROR An error occurred when writing received data to a local file, or "
			. 'an error was returned to libcurl from a write callback.',
		28 =>
			"CURLE_OPERATION_TIMEDOUT Operation timeout. The specified time-out period was reached according to the conditions.",
		35 =>
			'CURLE_SSL_CONNECT_ERROR A problem occurred somewhere in the SSL/TLS handshake. '
			. "Curl probably doesn't support this type of crypto.",
		43 =>
			'CURLE_BAD_FUNCTION_ARGUMENT Internal error. A function was called with a bad parameter.',
		45 =>
			"CURLE_INTERFACE_FAILED Interface error. A specified outgoing interface could not be "
			. "used. Set which interface to use for outgoing connections' source IP address with "
			. "CURLOPT_INTERFACE.",
		51 =>
			"CURLE_PEER_FAILED_VERIFICATION The remote server's SSL certificate or SSH md5 "
			. "fingerprint was deemed not OK.",
		53 => "CURLE_SSL_ENGINE_NOTFOUND The specified crypto engine wasn't found.",
		54 =>
			'CURLE_SSL_ENGINE_SETFAILED Failed setting the selected SSL crypto engine as default!',
		58 => 'CURLE_SSL_CERTPROBLEM Problem with the local client certificate.',
		59 => "CURLE_SSL_CIPHER Couldn't use specified cipher.",
		60 =>
			'CURLE_SSL_CACERT Peer certificate cannot be authenticated with known CA certificates.',
		64 => 'CURLE_USE_SSL_FAILED Requested FTP SSL level failed.',
		66 => 'CURLE_SSL_ENGINE_INITFAILED Initiating the SSL Engine failed.',
		77 =>
			'CURLE_SSL_CACERT_BADFILE Problem with reading the SSL CA cert (path? access rights?)',
		78 =>
			'CURLE_REMOTE_FILE_NOT_FOUND The resource referenced in the URL does not exist.',
		80 => 'CURLE_SSL_SHUTDOWN_FAILED Failed to shut down the SSL connection.',
		82 => 'CURLE_SSL_CRL_BADFILE Failed to load CRL file.',
		83 => 'CURLE_SSL_ISSUER_ERROR Issuer check failed.',
		90 =>
			'CURLE_SSL_PINNEDPUBKEYNOTMATCH Failed to match the pinned key specified with '
			. 'CURLOPT_PINNEDPUBLICKEY.',
		91 => 'CURLE_SSL_INVALIDCERTSTATUS Status returned failure when asked with '
			. 'CURLOPT_SSL_VERIFYSTATUS . ',
	);
	if ( defined $curl_exit_codes{$exit_code} ) {
		return $curl_exit_codes{$exit_code};
	}
	return;
}
1;
