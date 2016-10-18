#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use feature 'unicode_strings';
use English;
use Exporter qw(import);

our @EXPORT_OK = qw(hello_world);

sub hello_world {
	print "Hello World\n";
}
