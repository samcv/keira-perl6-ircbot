#!/usr/bin/env perl6
use v6;
use Test;
use JSON::Tiny;

use lib <lib>;
use classes;
plan 2;
#`{{my $thing = perlbot-file.new( filename => 'placeholder.json' );
my $result = $thing.load;
$result ~~ Promise;

isa-ok $result, Promise, "perlbot-file.load returns a Promise";

await $result;

is $result.status, Kept, "Promise is kept, indicating the file loaded properly";
}}
my $empty = perlbot-file.new( filename => 't/test-files/empty-json.json');
my $empty-result = $empty.load;

isa-ok $empty-result, Promise, "perlbot-file.load returns a Promise";

try await $empty-result;

is $empty-result.status, Broken, "Promise is broken when loading empty JSON file";
