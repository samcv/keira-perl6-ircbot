#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use feature 'unicode_strings';
use English;
use Encode::Detect;

use Exporter qw(import);
our @EXPORT_OK = qw(try_decode);

sub try_decode {
	my ( $string, $format ) = @_;
	print {*STDERR} "encoding is $format\n";
	if ( $format =~ /utf-8/i ) {
		print {*STDERR} "trying to decode with utf8\n";
		utf8::decode($string);
	}
	else {
		# Detect the encoding of the title with Encode::Detect module.
		# If that fails fall back to using utf8::decode instead.
		if ( !eval { $string = decode( 'Detect', $string ); 1 } ) {
			utf8::decode($string);
			print {*STDERR} "Falling back to utf8::decode\n";
		}
	}

	return $string;
}

1;
