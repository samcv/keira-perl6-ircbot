#!/usr/bin/env perl6
use IRC::Client;
use JSON::Pretty;
my $filename = 'said.pl';
my $proc = Proc::Async.new( 'perl', $filename, :w, :r );
my $promise;
for ^6 {
	if ! @*ARGS[$_] {
		note 'Usage: perlbot.pl "nick" "username" "real name" "server address" "server port" "server channel"';
		exit;
	}
}
my ($bot-username, $user-name, $real-name, $server-address, $server_port, $channel) = @*ARGS;
say "Nick: '$bot-username', Real Name: '$real-name', Server: '$server-address', Port: '$server_port', Channel: '$channel'";
my %secs-per-unit = 'years' => 15778800, 'months' => 1314900, 'days' => 43200,
                    'hours' => 3600, 'mins' => 60, 'secs' => 1;
sub convert-time ( $secs-since-epoch is copy ) is export  {
	my %time-hash;
	for %secs-per-unit.sort(*.value).reverse -> $pair {
		if $secs-since-epoch >= $pair.value {
			%time-hash{$pair.key} = $secs-since-epoch / $pair.value;
			$secs-since-epoch -= %time-hash{$pair.key} * $pair.value;
			last;
		}
	}
	return %time-hash;
}
sub format-time ( $time-since-epoch ) {
	return if $time-since-epoch == 0;
	my Str $tell_return;
	my $tell_time_diff = time - $time-since-epoch;
	return "[Just Now]" if $tell_time_diff < 1;
	my %time-hash = convert-time($tell_time_diff);
	$tell_return = '[';
	for %time-hash.keys -> $key {
		$tell_return ~= sprintf '%.2f', %time-hash{$key};
		$tell_return ~= $key.chop($key.chars - 1) ~ ' ';
	}
	$tell_return ~= 'ago]';
	return $tell_return;
}
class said2 does IRC::Client::Plugin {
	my %chan-event;
	has IO::Handle $!channel-event-fh;
	my Str $event-filename = $bot-username ~ '-event.json';
	my Str $event-filename-bak = $event-filename ~ '.bak';
	has Instant $!said-modified-time;
	has $.event_file_lock = Lock.new;
	has Supplier $.event_file_supplier = Supplier.new;
	has Supply $.event_file_supply = $!event_file_supplier.Supply;

	method irc-join ($e) {
		%chan-event{$e.nick}{'join'} = time.Int;
		%chan-event{$e.nick}{'host'} = $e.host;
		%chan-event{$e.nick}{'usermask'} = $e.usermask;

		$!event_file_supplier.emit( 1 );
		Nil;
	}
	method irc-part ($e) {
		%chan-event{$e.nick}{'part'} = time.Int;
		%chan-event{$e.nick}{'part-msg'} = $e.args;

		%chan-event{$e.nick}{'host'} = $e.host;
		%chan-event{$e.nick}{'usermask'} = $e.usermask;

		$!event_file_supplier.emit( 1 );
		Nil;
	}
	method irc-quit ($e) {
		%chan-event{$e.nick}{'quit'} = time.Int;
		%chan-event{$e.nick}{'quit-msg'} = $e.args;

		%chan-event{$e.nick}{'host'} = $e.host;
		%chan-event{$e.nick}{'usermask'} = $e.usermask;
		$!event_file_supplier.emit( 1 );
		Nil;
	}
	method irc-connected ($e) {
		if ! %chan-event  {
			say "Trying to load $event-filename";
			%chan-event = from-json( slurp $event-filename );
			say %chan-event;
		}
		$.event_file_supply.act( {
			# Probably not the best way to do things since this doesn't need to
			# be put in a 'start' block because of using '.act', but we can check
			# if the promise was kept (no exceptions) and then if so copy it
			# over the old event file
			my $event-file-bak-io = IO::Path.new($event-filename-bak);
			my $event-promise = start {
				say "Trying to update channel event data";
				spurt $event-filename-bak, to-json( %chan-event );
				# from-json will throw an exception if it can't process the file
				# we just wrote
				from-json(slurp $event-filename-bak);
			}
			$event-promise.result andthen $event-file-bak-io.copy($event-filename);

			say "UPDATED CHANNEL EVENT FILE";
		} );
		Nil;
	}
	method irc-privmsg-channel ($e) {
		%chan-event{$e.nick}{'spoke'} = time.Int;
		%chan-event{$e.nick}{'host'} = $e.host;
		%chan-event{$e.nick}{'usermask'} = $e.usermask;
		if $e.text ~~ /^'!seen '(\S+)/ {
			my $temp_nick = $0;
			my $seen-time;

			for %chan-event{$temp_nick}.sort.reverse -> $pair {
				my $second;
				if $pair.value ~~ /^\d+$/ {
					$second = format-time($pair.value);
				}
				else {
					$second = $pair.value;
				}
				$seen-time ~= ' ' ~ $pair.key.tc ~ ': ' ~ $second;
			}
			$.irc.send: :where($e.channel), :text("$0$seen-time") if %chan-event{$temp_nick};
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
		$proc.print("$channel >$bot-username\< \<{$e.nick}> {$e.text}\n");
		say "Trying to write to $filename : {$e.channel} >$bot-username\< \<{$e.nick}> {$e.text}";
		$!event_file_supplier.emit( 1 );
		Nil;
	}
}

my $irc = IRC::Client.new(
	nick     => $bot-username,
	userreal => $real-name,
	username => $user-name,
	host     => $server-address,
	channels => $channel,
	debug    => True,
	plugins  => said2.new);
$irc.run;
