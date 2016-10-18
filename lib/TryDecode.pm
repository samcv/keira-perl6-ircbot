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
	my ($string) = @_;

	# Detect the encoding of the title with Encode::Detect module.
	# If that fails fall back to using utf8::decode instead.
	if ( !eval { $string = decode( 'Detect', $string ); 1 } ) {
		utf8::decode($string);
	}

	return $string;
}
