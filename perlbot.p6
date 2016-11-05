#!/usr/bin/env perl6
use IRC::Client;
use JSON::Tiny;
my $said_out = Channel.new;
my $said_in = Channel.new;
my $filename = 'said.pl';
my $proc = Proc::Async.new( 'perl', $filename, :w, :r );
my $promise;
my $supply = Supply.interval(10);
for ^6 {
	if ! @*ARGS[$_] {
		note 'Usage: perlbot.pl "nick" "username" "real name" "server address" "server port" "server channel"';
		exit;
	}
}
my ($bot_username, $user_name, $real_name, $server_address, $server_port, $channel) = @*ARGS;
say "Nick: '$bot_username', Real Name: '$real_name', Server: '$server_address', Port: '$server_port', Channel: '$channel'";

class said2 does IRC::Client::Plugin {
	has Hash %.chan-event;
	has IO::Handle $!channel-event-fh;
	has Str $.channel-event-file = $bot_username ~ '-event.json';
	has Instant $!said-modified-time;
	has $.event_file_lock = Lock.new;
	method irc-join ($e) {
		%.chan-event{$e.nick}{'join'} = time.Int;
		%.chan-event{$e.nick}{'host'} = $e.host;
		%.chan-event{$e.nick}{'usermask'} = $e.usermask;
		Nil;
	}
	method irc-part ($e) {
		%.chan-event{$e.nick}{'part'} = time.Int;
		%.chan-event{$e.nick}{'part-msg'} = $e.args;

		%.chan-event{$e.nick}{'host'} = $e.host;
		%.chan-event{$e.nick}{'usermask'} = $e.usermask;
		Nil;
	}
	method irc-quit ($e) {
		%.chan-event{$e.nick}{'quit'} = time.Int;
		%.chan-event{$e.nick}{'quit-msg'} = $e.args;

		%.chan-event{$e.nick}{'host'} = $e.host;
		%.chan-event{$e.nick}{'usermask'} = $e.usermask;
		Nil;
	}
	method irc-connected ($e) {
		if ! %.chan-event  {
			$!channel-event-fh = open $.channel-event-file :r;
			%.chan-event = from-json($!channel-event-fh.slurp-rest);
			$!channel-event-fh.close;
			say %.chan-event;
		}
		Nil;
	}
	method irc-privmsg-channel ($e) {
		%.chan-event{$e.nick}{'spoke'} = time.Int;
		%.chan-event{$e.nick}{'host'} = $e.host;
		%.chan-event{$e.nick}{'usermask'} = $e.usermask;
		if $e.text ~~ /^'!seen '(\S+)/ {
			my $temp_nick = $0;
			my $seen-time = " Spoke: " ~ time.Int - %.chan-event{$temp_nick}{'spoke'} ;
			if %.chan-event{$temp_nick}{'join'} {
				$seen-time ~= " Join: " ~ time.Int - %.chan-event{$temp_nick}{'join'} ~ 's';
			}
			if %.chan-event{$temp_nick}{'part'} {
				$seen-time ~= " Part: " ~ time.Int - %.chan-event{$temp_nick}{'part'} ~ 's';
				if %.chan-event{$temp_nick}{'part-msg'} {
					$seen-time ~= " msg: ( { %.chan-event{$temp_nick}{'part-msg'} } )";
				}
			}
			if %.chan-event{$temp_nick}{'quit'} {
				$seen-time ~= " Quit: " ~ time.Int - %.chan-event{$temp_nick}{'quit'} ~ 's';
				if %.chan-event{$temp_nick}{'quit-msg'} {
					$seen-time ~= " msg: ( { %.chan-event{$temp_nick}{'quit-msg'} } )";
				}
			}
			$.irc.send: :where($e.channel), :text("Saw $0 $seen-time ago");
		}
		if !$proc.started or $filename.IO.modified > $!said-modified-time or $e.text ~~ /^RESET$/ {
			note "Starting $filename";
			$!said-modified-time = $filename.IO.modified;
			if $proc.started {
				note "trying to kill $filename";

				$proc.print("KILL\n");
				$proc.close-stdin;
				$proc.kill(9);
				await $promise;

			}
			$proc = Proc::Async.new( 'perl', $filename, :w, :r );
			$proc.stdout.lines.tap(  {
				my $line = $_;
				if ( $line ~~ s/^\%// ) {
					say "Trying to print to $channel : $line";
					#$.irc.send: :where($_) :text($line) for .channels;
					$.irc.send: :where($e.channel), :text($line);
				}
				else {
					say $line;
				}
			 } );
			 $promise = $proc.start;
		 }
		$proc.print("$channel >$bot_username\< \<{$e.nick}> {$e.text}\n");
		say "Trying to write to $filename : {$e.channel} >$bot_username\< \<{$e.nick}> {$e.text}";
		#$!proc.write: "$channel >$bot_username\< \<$e.nick> $e.text\n";
		start {
			$.event_file_lock.protect( {
				my $fh3 = open $.channel-event-file, :w;
				$fh3.say( to-json( %.chan-event) );
				close $fh3;
				say "UPDATED CHANNEL EVENT FILE";
			} );
		}
		Nil;
	}
}

my $irc = IRC::Client.new(
	nick     => $bot_username,
	userreal => $real_name,
	username => $user_name,
	host     => $server_address,
	channels => $channel,
	debug    => True,
	plugins  => said2.new);
$irc.run;
