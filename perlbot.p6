#!/usr/bin/env perl6
use v6.c;
use IRC::Client;
use Terminal::ANSIColor;
use lib 'lib';
use Perlbot;

sub MAIN ( Str $bot-username, Str $user-name, Str $real-name, Str $server-address,
           Int $server_port, Str $channel, $debug = False ) {
	my $irc = IRC::Client.new(
		nick     => $bot-username,
		userreal => $real-name,
		username => $user-name,
		host     => $server-address,
		channels => $channel,
		debug    => $debug.Bool,
		plugins  => said2.new);
	$irc.run;
}
# vim: noet
