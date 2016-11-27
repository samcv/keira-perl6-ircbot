#!/usr/bin/env perl6
use v6;
use Test;

use lib <lib>;
use PerlEval;
plan 2;
is perl-eval( :lang<perl6>, :cmd("say 'test'")), "STDOUT«test␤»", "test perl6 eval";
is perl-eval( :lang<perl>, :cmd('print "test\n"')), "STDOUT«test␤»", "test perl5 eval";
