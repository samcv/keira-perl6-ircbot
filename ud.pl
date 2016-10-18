#!/usr/bin/env perl
use warnings;
use strict;
use utf8;
use feature 'unicode_strings';
use WebService::UrbanDictionary;

my $ud_request = $ARGV[0];

my ( $definition, $example );
my $ud = WebService::UrbanDictionary->new;

my $results = $ud->request($ud_request);
for my $each ( @{ $results->definitions } ) {
	$definition = $each->definition;
	$example    = $each->example;
	last;
}
if ( !defined $definition && !defined $example ) {
	exit 1;
}
print q(%) . 'DEF' . q(%) . $definition . q(%) . 'EXA' . q(%) . $example . "\n";
exit 0;
