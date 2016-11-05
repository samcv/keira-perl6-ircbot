#!/usr/bin/env perl6
use IRC::Client;
use JSON::Tiny;
my $said_out = Channel.new;
my $said_in = Channel.new;
my $filename = 'said.pl';
my $proc = Proc::Async.new( 'perl', $filename, :w, :r );
my $promise;
for ^6 {
	if ! @*ARGS[$_] {
		note 'Usage: perlbot.pl "nick" "username" "real name" "server address" "server port" "server channel"';
		exit;
	}
}
my ($bot_username, $user_name, $real_name, $server_address, $server_port, $channel) = @*ARGS;
say "Nick: '$bot_username', Real Name: '$real_name', Server: '$server_address', Port: '$server_port', Channel: '$channel'";
constant Secs-Per-Min = 60;
constant Secs-Per-Hour = Secs-Per-Min * 60;
constant Secs-Per-Day = Secs-Per-Hour * 12;
constant Secs-Per-Year = Secs-Per-Day * 365.25;
constant Secs-Per-Month = Secs-Per-Year / 12;
sub convert-time ( $secs-since-epoch is copy )  {
	my %time-hash;
	if $secs-since-epoch >= Secs-Per-Year {
		%time-hash{'years'} = $secs-since-epoch / Secs-Per-Year;
		$secs-since-epoch   = $secs-since-epoch - %time-hash{'years'} * Secs-Per-Year;
	}
	if $secs-since-epoch >= Secs-Per-Day {
		%time-hash{'days'} = $secs-since-epoch / Secs-Per-Day;
		$secs-since-epoch  = $secs-since-epoch - %time-hash{'days'} * Secs-Per-Day;
	}
	if $secs-since-epoch >= Secs-Per-Hour {
		%time-hash{'hours'} = $secs-since-epoch / Secs-Per-Hour;
		$secs-since-epoch   = $secs-since-epoch - %time-hash{'hours'} * Secs-Per-Hour;
	}
	if $secs-since-epoch >= Secs-Per-Min {
		%time-hash{'mins'} = $secs-since-epoch / Secs-Per-Min;
		$secs-since-epoch  = $secs-since-epoch - %time-hash{'mins'} * Secs-Per-Min;
	}
	%time-hash{'secs'} = $secs-since-epoch if $secs-since-epoch > 0;
	return %time-hash;
}
sub format-time ( $time-since-epoch ) {
	my Str $tell_return;
	my $tell_time_diff = time - $time-since-epoch;

	my %time-hash = convert-time($tell_time_diff);
	$tell_return = '[';
	if ( %time-hash{'years'} ) {
		$tell_return ~= %time-hash{'years'} ~ 'y ';
	}
	if (  %time-hash{'days'} ) {
		$tell_return ~= %time-hash{'days'} ~ 'd ';
	}
	if (  %time-hash{'hours'} ) {
		$tell_return ~= %time-hash{'hours'} ~ 'h ';
	}
	if ( %time-hash{'mins'} ) {
		$tell_return ~= %time-hash{'mins'} ~ 'm ';
	}
	if ( %time-hash{'secs'} ) {
		$tell_return ~= %time-hash{'secs'} ~ 's ';
	}
	$tell_return ~= 'ago]';
	return $tell_return;
}
class said2 does IRC::Client::Plugin {
	my %chan-event;
	has IO::Handle $!channel-event-fh;
	my Str $event_filename = $bot_username ~ '-event.json';
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
			$!channel-event-fh = open $event_filename, :r;
			%chan-event = from-json($!channel-event-fh.slurp-rest);
			$!channel-event-fh.close;
			say %chan-event;
		}
		$.event_file_supply.act( {
			try {
				my $fh3 = open $event_filename, :w;
				$fh3.say( to-json( %chan-event) );
				close $fh3;
				CATCH {
					say "Problem writing to file: $_";
					$event_filename ~= (^9).pick;
					say "Falling back and using $event_filename";
					my $fh-backup = open $event_filename, :w;
					$fh-backup.say( to-json( %chan-event) );
					close $fh-backup;
				}
			}
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
			my $seen-time = " Speak: " ~ format-time( %chan-event{$temp_nick}{'spoke'} );
			if %chan-event{$temp_nick}{'join'} {
				$seen-time ~= " Join: " ~ format-time( %chan-event{$temp_nick}{'join'} );
			}
			if %chan-event{$temp_nick}{'part'} {
				$seen-time ~= " Part: " ~ format-time( %chan-event{$temp_nick}{'join'} );
				if %chan-event{$temp_nick}{'part-msg'} {
					$seen-time ~= " msg: ( { %chan-event{$temp_nick}{'part-msg'} } )";
				}
			}
			if %chan-event{$temp_nick}{'quit'} {
				$seen-time ~= " Quit: " ~ format-time( %chan-event{$temp_nick}{'join'} );
				if %chan-event{$temp_nick}{'quit-msg'} {
					$seen-time ~= " msg: ( { %chan-event{$temp_nick}{'quit-msg'} } )";
				}
			}
			$.irc.send: :where($e.channel), :text("Saw $0 $seen-time");
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
		$!event_file_supplier.emit( 1 );
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
