#!/usr/bin/env perl6
use IRC::Client;
use Terminal::ANSIColor;
use lib 'lib';
use Perlbot;

sub MAIN ( $bot-username, $user-name, $real-name, $server-address, $server_port, $channel ) {
	note "Nick: '$bot-username', Real Name: '$real-name', Server: '$server-address', Port: '$server_port', Channel: '$channel'";

	my $irc = IRC::Client.new(
		nick     => $bot-username,
		userreal => $real-name,
		username => $user-name,
		host     => $server-address,
		channels => $channel,
		debug    => False,
		plugins  => said2.new);
	$irc.run;
}
# vim: noet
