#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use feature 'unicode_strings';
use English;
use URL::Search 'extract_urls';

sub locate_urls {
	my ($search_string) = @_;
	my @url_array = extract_urls($search_string);
	return @url_array;
}

1;

# vim: tabstop=4 expandtab!
