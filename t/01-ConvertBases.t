#!/usr/bin/env perl6
use v6;
use Test;
plan 64;
use lib 'lib';
use ConvertBases;
my $uni = "This is a Test String 🐧";
my $bin = "1010100 1101000 1101001 1110011 100000 1101001 1110011 100000 1100001 100000 1010100 1100101 1110011 1110100 100000 1010011 1110100 1110010 1101001 1101110 1100111 100000 11111010000100111";
my $oct = "124 150 151 163 40 151 163 40 141 40 124 145 163 164 40 123 164 162 151 156 147 40 372047",
my $dec = "84 104 105 115 32 105 115 32 97 32 84 101 115 116 32 83 116 114 105 110 103 32 128039";
my %hash =
    uni => $uni,
    unicode => $uni,
    oct => $oct,
    octal => $oct,
    bin => $bin,
    binary => $bin,
    dec => $dec,
    decimal => $dec;
my @list = %hash.keys;
my @all-list = @list X @list;
for @all-list -> $i {
    is convert-bases(%hash{$i[0]}, :from( $i[0] ), :to( $i[1] ) ), %hash{$i[1]}, "$i[0] to $i[1]";
}
done-testing;
