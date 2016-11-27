#!/usr/bin/env perl6
use v6;
use Test;
plan 8;
use lib 'lib';
use-ok 'classes';
use-ok 'format-time';
use-ok 'PerlEval';
use-ok 'IRC::TextColor';

use-ok 'ConvertBases';
use-ok 'IRC::TextColor';

use-ok 'IRCPlugin::Keira';
use-ok 'IRCPlugin::UrbanDictionary';

done-testing;
