#!/usr/bin/env perl6
use v6;
use Test;
use JSON::Tiny;

use lib <lib>;
use classes;
#plan 5;
my $file-orig = slurp 't/test-files/placeholder.json';

my $thing = perlbot-file.new( filename => 't/test-files/placeholder.json' );
my $result = $thing.load;

isa-ok $result, Promise, "perlbot-file.load returns a Promise";

try sink await $result;

is $result.status, Kept, "Promise is kept, indicating the file loaded properly";

try sink await $thing.save;
my $new-file =  slurp 't/test-files/placeholder.json';
is $new-file, $file-orig, "Test they are the same";

my $empty = perlbot-file.new( filename => 't/test-files/empty-json.json');
my $empty-result = $empty.load;

isa-ok $empty-result, Promise, "perlbot-file.load returns a Promise";

try sink await $empty-result;

is $empty-result.status, Broken, "Promise is broken when loading empty JSON file";
