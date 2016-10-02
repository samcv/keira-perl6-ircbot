#!/usr/bin/env perl
# Perl script for processing channel join and part messages
use strict;
use warnings;
use utf8;
use English;
our $VERSION = 0.4;

my ($nick, $channel, $event, $bot_username) = @ARGV;
print "Nick $nick $event channel $channel\n";
