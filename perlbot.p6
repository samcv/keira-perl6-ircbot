#!/usr/bin/env perl6
use IRC::Client;
my $said_out = Channel.new;
my $said_in = Channel.new;
my $filename = 'said.pl';
my $proc = Proc::Async.new( 'perl', $filename, :w, :r );
my $promise;
note 'Usage: perlbot.pl "nick" "username" "real name" "server address" "server port" "server channel"';
my ($bot_username, $user_name, $real_name, $server_address, $server_port, $channel) = @*ARGS;
say "Nick: '$bot_username', Real Name: '$real_name', Server: '$server_address', Port: '$server_port', Channel: '$channel'";
my $modified_time;
class said2 does IRC::Client::Plugin {
	method irc-connected ($e) {


	}
	method irc-privmsg-channel ($e) {
		my $body     = $e.text;
		my $who_said = $e.nick;
		my $channel  = $e.channel;
		if !$proc.started or $filename.IO.modified > $modified_time {
			note "Starting $filename";
			$modified_time = $filename.IO.modified;
			if $proc.started {
				note "trying to kill $filename";

				$proc.print("KILL\n");
				$proc.close-stdin;
				await $promise;

			}
			$proc = Proc::Async.new( 'perl', $filename, :w, :r );
			$proc.stdout.lines.tap(  {
				my $line = $_;
				if ( $line ~~ s/^\%// ) {
					say "Trying to print to $channel : $line";
					#$.irc.send: :where($_) :text($line) for .channels;
					$.irc.send: :where($channel), :text($line);
				}
				else {
					say $line;
				}
			 } );
			 $promise = $proc.start;
		 }
		$proc.print("$channel >$bot_username\< \<$who_said> $body\n");
		say "Trying to write to said.in.pl : $channel >$bot_username\< \<$who_said> $body";
		#$!proc.write: "$channel >$bot_username\< \<$who_said> $body\n";
		Nil;
	}
}

my $irc = IRC::Client.new(
	nick => $bot_username,
	userreal => $real_name,
	username => $user_name,
	host => $server_address,
	channels => $channel,
	debug => True,
	plugins => said2.new);
	$irc.run;
