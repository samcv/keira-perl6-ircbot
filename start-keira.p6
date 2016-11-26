#!/usr/bin/env perl6
use v6.c;
# Ecosystem modules
use IRC::Client;
# My modules
use lib 'lib';
use IRCPlugin::Keira;
use IRCPlugin::UrbanDictionary;

sub MAIN ( Str $bot-username, Str $user-name, Str $real-name, Str $server-address,
           Int $server_port, Str $channel, $debug = False ) {
	my $irc = IRC::Client.new(
		nick     => $bot-username,
		userreal => $real-name,
		username => $user-name,
		host     => $server-address,
		channels => $channel,
		debug    => $debug.Bool,
		plugins  => (Keira.new, Urban-Dictionary.new)
	);
	$irc.run;
}
# vim: noet
