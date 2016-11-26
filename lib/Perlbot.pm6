use v6.c;
use IRC::Client;
use Text::Markov;
use Terminal::ANSIColor;
use WWW::Google::Time;
use IRCTextColor;
use ConvertBases;
use classes;
=head1 What
=para
A Perl 6+5 bot using the IRC::Client Perl 6 module

=head1 Description
=para
This is an IRC bot in Perl 5 and 6. It was originally only in Perl 5 but the core has now been rewriten
in Perl 6, and the rest is being ported over now.


class said2 does IRC::Client::Plugin {
	has Str $.said-filename = 'said.pl';
	has Proc::Async $.proc = Proc::Async.new( 'perl', $!said-filename, :w, :r );
	my $promise;
	# Describes planned future events. Mode can be '-b' to unban after a specified amount of time.
	# If mode is `msg` the descriptor will be their nickname, whose value is set to the message.
	my %chan-mode;     # %chan-mode{$e.server.host}{channel}{time}{mode}{descriptor}
	my %curr-chanmode; # %curr-chanmode{$e.server.host}{$channel}{time}{mode}{descriptor}
	my %ops;            # %ops{'nick'}{usermask/hostname}
	has %.strings = { 'unauthorized' => "Your nick/hostname/usermask did not match. You are not authorized to perform this action" };
	has Instant $.last-saved-event = now;
	has Instant $.last-saved-history = now;
	has Instant $.last-saved-ban = now;
	state history-class $history-file;
	state chanevent-class $chanevent-file;

	has IO::Handle $!channel-event-fh;
	has Instant $!said-modified-time;
	has Supplier $.event_file_supplier = Supplier.new;
	has Supply $.event_file_supply = $!event_file_supplier.Supply;
	has Supply:U $.tick-supply;
	has Supply:D $.tick-supply-interval = $!tick-supply.interval(1);
	my $markov;
	my $markov-lock = Lock.new;
	sub set-mode ( $e, Str $argument, Str :$mode) {
		$e.irc.send-cmd: 'MODE', $e.channel, $mode, $argument, :server($e.server);
	}
	# Bans the mask from specified channel
	sub ban ( $e, $mask, $secs) {
		my $ban-for = now.Rat + $secs;
		%chan-mode{$e.server.host}{$e.channel}{$ban-for}{'-b'} = $mask;
		set-mode($e, :mode<+b>, $mask);
		$e.irc.send: :where($e.channel) :text("Banned for {format-time($ban-for)}");
	}
	sub unban ( $e, $mask) {
		set-mode($e, :mode<-b>, $mask);
	}
	sub give-ops ( $e, $nick) {
		set-mode($e, :mode<+o>, $nick);
	}
	sub take-ops ( $e, $nick) {
		set-mode($e, :mode<-o>, $nick);
	}
	sub kick ( $e, $user, $message ) {
		$e.irc.send-cmd: 'KICK', $e.channel, $user, $message, :server($e.server);
	}
	sub topic ( $e, $topic ) {
		$e.irc.send-cmd: 'TOPIC', $e.channel, $topic, :server($e.server);
	}
	# Receives an object and checks that the sender is an op
	sub check-ops ( $e ) {
		if %ops{$e.nick} {
			if $e.host eq %ops{$e.nick}{'hostname'} and $e.usermask eq %ops{$e.nick}{'usermask'} {
				return 1;
			}
		}
		0;
	}
	sub send-ping ( $e ) {
		$e.irc.send-cmd: 'PING', $e.server.host, :server($e.server);
	}

	sub markov ( Int $length ) returns Str {
			my $markov-text = $markov-lock.protect( { $markov.read(75) } );
			$markov-text ~~ s:g/(\s+)('.'|'!'|':'|';'|',') /$1/;
			$markov-text.Str;
	}
	multi markov-feed ( Str $string is copy ) {
		#say "Got string: [$string]";
		if $string !~~ / ^ '!'|'s/' / {
			$string ~~ s/$/ /;
			$string ~~ s:g/(\S+) ('.'|'!'|':'|';'|',') ' '/ $0 $1 /;
			#say "Processed string: [$string]";
			$markov-lock.protect( {	$markov.feed( $string.words ) } );
		}
	}
	method irc-mode-channel ($e) {
		my @mode-pairs = $e.modes;
		my $server = $e.server;
		my $mode-type = @mode-pairs.shift;
		$mode-type = $mode-type.key ~ $mode-type.value;
		my $mode = @mode-pairs.join;
		if $mode-type ~~ /'b'/ {
			my $user = $mode;
			$mode ~~ m/ ^ $<nick>=( \S+ ) '!' /;
			my $nick = $<nick>;
			$nick ~~ s:g/ (\S*)? '*' (\S*)?/'$0'\\S*'$1'/;
			$nick ~~ s/ '*' /\\S*/;
			say "nick regex: $nick";
			for $chanevent-file.get-hash.keys -> $key {
				if $key ~~ /<$nick>/ {
				}
			}
		}
	}
	method irc-join ($e) {
		$chanevent-file.update-event($e);
		$!event_file_supplier.emit( 0 );
		Nil;
	}
	method irc-part ($e) {
		$chanevent-file.update-event($e);
		$!event_file_supplier.emit( 0 );
		Nil;
	}
	method irc-quit ($e) {
		$chanevent-file.update-event($e);
		$!event_file_supplier.emit( 0 );
		Nil;
	}
	method irc-connected ($e) {
		if ! $history-file {
			$history-file = history-class.new( filename => $e.server.current-nick ~ '-history.json' );
			$history-file.load;
		}
		if ! $chanevent-file {
			$chanevent-file = chanevent-class.new( filename => $e.server.current-nick ~ '-event.json' );
			$chanevent-file.load;
		}
		state $ops-file;
		if ! $ops-file {
			$ops-file = perlbot-file.new( filename => $e.server.current-nick ~ '-ops.json' );
			$ops-file.load;
			%ops = $ops-file.get-hash;
		}
		state $chanmode-file;
		if ! $chanmode-file {
			$chanmode-file = perlbot-file.new( filename => $e.server.current-nick ~ '-ban.json' );
			$chanmode-file.load;
			%chan-mode = $chanmode-file.get-hash;
		}
		$.tick-supply-interval.tap( {
			if $_ %% 60 {
				send-ping($e);
			}
			for	$e.server.channels -> $channel {
				for %chan-mode{$e.server.host}{$channel}.keys -> $time {
					if $time < now {
						for  %chan-mode{$e.server.host}{$channel}{$time}.kv -> $mode, $descriptor {
							say "Channel: [$channel] Mode: [$mode] Descriptor: [$descriptor]";
							if $mode ~~ / ^ '-'|'+' / {
								$.irc.send-cmd: 'MODE', "$channel $mode $descriptor", $e.server;
								%chan-mode{$e.server.host}{$channel}{$time}:delete;
							}
							elsif $mode eq 'remind' {
								for %chan-mode{$e.server.host}{$channel}{$time}{'tell'} -> %values {
									#%values.gist.say;
									#%values<message>.say;
									my $formated = "{%values<to>}: {%values<from>} said, {%values<message>} " ~ format-time(%values<when>);
									$.irc.send: :where($channel) :text( $formated );
								}
								%chan-mode{$e.server.host}{$channel}{$time}:delete;
							}
						}
					}
				}
			}
		 } );
		$.event_file_supply.act( -> $msg {
			start {
				note "Received message $msg for saving";
				my @write-promises;

				push @write-promises, $chanevent-file.save($msg.Int);

				push @write-promises, $history-file.save($msg.Int);

				$chanmode-file.set-hash(%chan-mode);
				push @write-promises, $chanmode-file.save($msg.Int);
				note "awaiting processes";
				await Promise.allof(@write-promises);
				note "Done saving";
				if $msg >= 3 {
					$.irc.quit;
				}
			}
		} );
		signal(SIGINT).tap( {
			note "Trying to quit. Received SIGINT";
			$!event_file_supplier.emit( 3 )
		} );
		start {
			$markov-lock.protect( { $markov = Text::Markov.new } );
			for $history-file.get-hash.values -> $value {
				markov-feed( $value{'text'} );
			}
		}
		Nil;
	}
	method irc-privmsg-channel ($e) {
		my $unrec-time = "Unrecognized time format. Use X ms, sec(s), second(s), min(s), minutes(s), hour(s), week(s), month(s) or year(s)";
		say $e.WHAT;
		my $bot-nick = $e.server.current-nick;
		my $now = now.Rat;
		my $timer_1 = now;
		$chanevent-file.update-event($e);
		my $running;

		# FIXME maybe enclose in a start block?
		for	$e.server.channels -> $channel {
			for %chan-mode{$e.server.host}{$channel}.keys -> $time {
				if $time < now {
					for  %chan-mode{$e.server.host}{$channel}{$time}.kv -> $mode, $descriptor {
						#say "Channel: [$channel] Mode: [$mode] Descriptor: [$descriptor]";
						if $mode eq 'tell' {
							for %chan-mode{$e.server.host}{$channel}{$time}{'tell'} -> %values {
								last if %values<to> ne $e.nick;
								#%values.gist.say;
								#%values<message>.say;
								my $formated = "{%values<to>}: {%values<from>} said, {%values<message>} " ~ format-time(%values<when>);
								$.irc.send: :where($channel) :text( $formated );
							}
							%chan-mode{$e.server.host}{$channel}{$time}:delete;
						}
					}
				}
			}
		}
		my $timer_2 = now;
		note "1->2: {$timer_2 - $timer_1}";
		if (^30).pick.not {
			start { $.irc.send: :where($e.channel) :text( markov(75) ) }
		}
		my $timer_3 = now;
		note "2->3: {$timer_3 - $timer_2}";
		given $e.text {
			=head2 Text Substitution
			=para
			s/before/after/gi functionality. Use g or i at the end to make it global or case insensitive

			when m:i{ ^ 's/' (.+?) '/' (.*) '/'? } {
				my Str $before = $0.Str;
				my Str $after = $1.Str;
				# We need to do this to allow Perl 5/PCRE style regex's to work as expected in Perl 6
				# And make user input safe
				# Change from [a-z] to [a..z] for character classes
				while $before ~~ /'[' .*? <( '-' )> .*? ']'/ {
					$before ~~ s:g/'[' .*? <( '-' )> .*? ']'/../;
				}
				# Escape all the following characters
				for Qw[ - & ! " ' % = , ; : ~ ` @ { } < > ] ->  $old {
					$before ~~ s:g/$old/{"\\" ~ $old}/;
				}
				$before ~~ s:g/'#'/'#'/; # Quote all hashes #
				$before ~~ s:g/ '$' .+ $ /\\\$/; # Escape all $ unless they're at the end
				$before ~~ s:g/'[' (.*?) ']'/<[$0]>/; # Replace [a..z] with <[a..z]>
				$before ~~ s:g/' '/<.ws>/; # Replace spaces with <.ws>
				my $options;
				=para
				If the last character is a slash, we assume any slashes in the $after term are literal
				( Except for the last one )
				If not, then anything after the last slash is a specifier

				if $after !~~ s/ '/' $ // {
					if $after ~~ s/ (.*?) '/' (.+) /$0/ {
						$options = ~$1;
					}
				}
				say "Before: {colored($before.Str, 'green')} After: {colored($after.Str, 'green')}";
				say "Options: {colored($options.Str, 'green')}" if $options;
				my ( $global, $case )  = False xx 2;
				$global = ($options ~~ / g /).Bool if $options.defined;
				$case = ($options ~~ / i /).Bool if $options.defined;
				say "Global is $global Case is $case";
				$before = ':i ' ~ $before if $case;
				for $history-file.get-hash.sort.reverse.values -> $value {
					say $value.gist;
					my Str $sed-text = $value<text>;
					my Str $sed-nick = $value<nick>;
					say $sed-text;
					my $was-sed = False;
					$was-sed = $value{'sed'} if $value{'sed'};
					next if $sed-text ~~ m:i{ ^ 's/' };
					next if $sed-text ~~ m{ ^ '!' };
					if $sed-text ~~ m/<$before>/ {
						$sed-text ~~ s:g/<$before>/$after/ if $global;
						$sed-text ~~ s/<$before>/$after/ if ! $global;
						irc-style($sed-nick, :color<teal>);
						my $now = now.Rat;
						$history-file.add-entry( $now, text => "<$sed-nick> $sed-text", nick => $bot-nick, sed => True );
						if ! $was-sed {
							$.irc.send: :where($e.channel) :text("<$sed-nick> $sed-text");
						}
						else {
							$.irc.send: :where($e.channel) :text("$sed-text");
						}
						last;
					}
				}
			}
		}
		if $e.text.starts-with('!') {
			given $e.text {
				when / ^ '!derp' / {
					start { $.irc.send: :where($e.channel) :text( markov(75) ) }
				}
				=head2 Seen
				=para
				Replys with the last time the specified user has spoke, joined, quit or parted.
				`Usage: !seen nickname`

				when / ^ '!seen ' $<nick>=(\S+) / {
					my $seen-nick = ~$<nick>;
					last if ! $chanevent-file.nick-exists($seen-nick);
					my $seen-time;
					for $chanevent-file.get-nick-event($seen-nick).sort.reverse -> $pair {
						my $second;
						if $pair.key eq 'mentioned' {
							next;
						}
						elsif $pair.value ~~ /^ \d* '.'? \d* $/ {
							$second = format-time($pair.value);
						}
						else {
							$second = $pair.value;
						}
						$seen-time ~= irc-text($pair.key.tc, :style<underline>) ~ ': ' ~ $second ~ ' ';
					}
					if $chanevent-file.nick-exists($seen-nick) {
						irc-style($seen-nick, :color<blue>, :style<bold>);
						$.irc.send: :where($e.channel), :text("$seen-nick $seen-time");
					}
				}
				=head2 Saving Channel Event Data
				=para The command `!SAVE` will cause the channel event data and history file to be saved.
				Normally it will save when the data changes in memory provided it hasn't already saved
				within the last 10 seconds

				when /^'!SAVE'/ {
					$!event_file_supplier.emit( 1 );
				}
				=head2 Tell
				=para Syntax: `!tell nickname message` or `!tell nickname in 10 minutes message`
				=para Will tell the specified nickname the message the next time they speak in channel

				when / ^ '!tell ' $<nick>=(\S+) ' in ' $<time>=(\d+) ' ' $<units>=(\S+) ' '? $<message>=(.*) / {
					say "Nick [{$<nick>}] Units [{$<units>}] Time [{$<time>}] Message [{$<message>}]";
					if $chanevent-file.nick-exists($<nick>) {
						my $message = ~$<message>;
						my $got = string-to-secs("$<time> $<units>");
						if !$got or $<nick> eq 'in' {
							$.irc.send: :where($e.channel), :text("Syntax: !tell nick message or !tell nick in 10 units $unrec-time");
							last;
						}
						# If we know about this person set it
						my $now = now.Rat + $got;
						%chan-mode{$e.server.host}{$e.channel}{$now}{'tell'}{'from'} = $e.nick;
						%chan-mode{$e.server.host}{$e.channel}{$now}{'tell'}{'to'} = ~$<nick>;
						%chan-mode{$e.server.host}{$e.channel}{$now}{'tell'}{'message'} = $message;
						%chan-mode{$e.server.host}{$e.channel}{$now}{'tell'}{'when'} = now.Rat;
						$.irc.send: :where($e.channel), :text("{$e.nick}: I will relay the message to {$<nick>}");
					}
					else {
						$.irc.send: :where($e.channel), :text("{e.nick}: I have never seen this person before");
					}
					# We should do it the next time they speak

				}
				when / ^ '!tell ' $<nick>=(\S+) ' '$<message>=(.*) / {
					say "Nick [{$<nick>}] Units [{$<units>}] Time [{$<time>}] Message [{$<message>}]";
					if $chanevent-file.nick-exists(~$<nick>) {
						my $message = ~$<message>;
						my $got = string-to-secs("$<time> $<units>");
						# If we know about this person set it
						my $now = now.Rat + $got;
						%chan-mode{$e.server.host}{$e.channel}{$now}{'tell'}{'from'} = $e.nick;
						%chan-mode{$e.server.host}{$e.channel}{$now}{'tell'}{'to'} = ~$<nick>;
						%chan-mode{$e.server.host}{$e.channel}{$now}{'tell'}{'message'} = $message;
						%chan-mode{$e.server.host}{$e.channel}{$now}{'tell'}{'when'} = now.Rat;
						$.irc.send: :where($e.channel), :text("{$e.nick}: I will relay the message to {$<nick>}");
					}
					else {
						$.irc.send: :where($e.channel), :text("{e.nick}: I have never seen this person before");
					}
					if $<time> and $<units> {
						# We have to do it in a specified number of mins
						my $got = string-to-secs("$<time> $<units>");
						say $got;
						$.irc.send: :where($e.channel), :text("{$e.nick}: $got");

					}
					# We should do it the next time they speak

				}
				=head1 Operator Commands
				=para
				People who have been added as an operator in the 'botnick-ops.json' file will be allowed
				to perform the following commands if their nick, hostname and usermask match those
				in the file.

				=head2 Ban
				=para
				The specified user will be banned by 30 minutes at default. You can override this and
				set a specific number of seconds to ban for instead. The bot will automatically unban
				the person once this time period is up, as well as printing to the channel how long the
				user has been banned for. Usage: `!ban nick`.

				when / ^ '!ban ' (\S+) ' '? (.+) / {
					if ! check-ops($e) {
						$.irc.send: :where($e.channel), :text(%.strings<unauthorized>);
						last;
					}
					say "e text: [{$e.text}]";
					my $ban-who = ~$0;
					my $ban-len = ~$1;
					if $ban-len.defined {
						$ban-len = string-to-secs($ban-len);
						if ! $ban-len {
							$.irc.send: :where($e.channel), :text($unrec-time);
							last;
						}
					}
					else {
						$ban-len = string-to-secs("30 minutes") if ! $ban-len.defined;
					}
					ban($e, "$ban-who*!*@*", $ban-len);
				}
				=head2 Unban
				=para `Usage: !unban nick`

				when / ^ '!unban ' (\S+) ' '? (\S+)? / {
					my $ban-who = $0;
					my $ban-len = $1;
					check-ops($e);
					if check-ops($e) {
						unban($e, "$ban-who*!*@*");
					}
					else {
						$.irc.send: :where($e.channel), :text(%.strings<unauthorized>);
					}
				}

				=head2 Op
				=para Gives ops to specified user, or if no user is specified, gives operator to the
				user who did the command. `Usage: !op` or `!op nickname`.

				when / ^ '!op' ' '? (\S+)? / {
					if check-ops($e) {
						my $op-who = $0.defined ?? $0 !! $e.nick;
						give-ops($e, $op-who);
					}
					else {
						$.irc.send: :where($e.channel), :text(%.strings<unauthorized>);
					}
				}
				=head2 DeOp
				=para Takes ops away from the specified user, or if no user is specified, removes operator
				status from the user who did the command. `Usage: !deop` or `!deop nickname`.

				when / ^ '!deop' ' '? (\S+)? / {
					if check-ops($e) {
						my $op-who = $0.defined ?? $0 !! $e.nick;
						take-ops($e, $op-who);
					}
					else {
						$.irc.send: :where($e.channel), :text(%.strings<unauthorized>);
					}
				}
				=head2 Kick
				=para Kicks the specified user from the channel. You are also allowed to specify a
				custom kickmessage as well. `Usage: !kick nickname` or `!kick nickname custom message`.

				when m{ ^ '!kick ' $<kick-who>=(\S+) ' '? $<message>=(.+)? } {
					my $message = $<message> ?? $<message> !! "Better luck next time";
					if check-ops($e) {
						kick( $e, $<kick-who>, $message );
					}
					else {
						$.irc.send: :where($e.channel), :text(%.strings<unauthorized>);
						if $<kick-who> eq $e.nick {
							kick( $e, $e.nick, $message )
						}
					}
				}
				=head2 Topic
				=para Sets the topic. `Usage: !topic new topic message here`.

				when / ^ '!topic ' $<topic>=(.*) / {
					if check-ops($e) {
						topic($e, $<topic>);
					}
				}
				=head1 Hexidecimal/Decimal/Unicode conversions
				=para You can convert between any of these three using the general syntax `!from2to`

				=para When converting from numerical each value that is a different number is
				delimited by spaces.  Examples are below.

				=head2 Get Unicode Codepoints
				=para Usage: `!hex2uni 🐧ABCD`
				=para Output: `1F427 41 42 43 44`
				=para Will get the Unicode codepoints in hex for a given string.

				=head2 Convert from Unicode Codepoints to Characters
				=para Usage: `!uni2hex 1F427 41 42 43 44`
				=para Output: `🐧ABCD`

				when / ^ '!' $<from>=(\S+) '2' $<to>=(\S+) ' ' $<string>=(.*) / {
					$.irc.send: :where($e.channel), :text( convert-bases(:from(~$<from>), :to(~$<to>), ~$<string>) );
				}
				when / ^ '!rev ' $<torev>=(.*) / {
					$.irc.send: :where($e.channel), :text($<torev>.flip);
				}
				when / ^ '!uc ' $<touc>=(.*) / {
					$.irc.send: :where($e.channel), :text($<touc>.uc);
				}
				when / ^ '!lc ' $<tolc>=(.*) / {
					$.irc.send: :where($e.channel), :text($<tolc>.lc);
				}
				=head2 Mentioned
				=para Gets the last time the specified person mentioned any users the bot knows about.
				=para `Usage: !mentioned nickname`

				when / ^ '!mentioned '(\S+) / {
					my $temp_nick = $0;
					if $chanevent-file.get-nick-event($temp_nick){'mentioned'}:exists {
						my $second = "$temp_nick mentioned, ";
						for $chanevent-file.get-nick-event($temp_nick){'mentioned'}.sort(*.value).reverse -> $pair {
							$second ~= "{$pair.key}: {format-time($pair.value)} ";
						}
						$.irc.send: :where($e.nick), :text($second);
					}
				}
				=head2 Time
				=para Gets the current time in the specified location. Uses Google to do the lookups.
				=para `Usage !time Location`

				when / ^ '!time ' (.*) / {
					my $time-query = ~$0;
					start {
						my %google-time;
						try { %google-time = google-time-in($time-query) };
						if !$! {
							$.irc.send: :where($e.channel), :text("It is now {%google-time<str>} in {irc-text(%google-time<where>, :color<blue>, :style<bold>)}");
						}
						else {
							$.irc.send: :where($e.channel), :text("Cannot find the time for {irc-text($time-query, :color<blue>, :style<bold>)}");
						}
					}
				}
				=head2 Perl 6 Eval
				=para Evaluates the requested Perl 6 code and returns the output of standard out
				and error messages.
				=para `Usage: !p6 my $var = "Hello Perl 6 World!"; say $var`

				=head2 Perl 5 Eval
				=para Evaluates the requested Perl 5 code and returns the output of standard out
				and error messages.
				=para `Usage: !p my $var = "Hello Perl 5 World!\n"; print $var`

				when / ^ $<lang>=('!p '|'!p6 ') $<cmd>=(.+) / {
					my $eval-proc;
					if $<lang> eq '!p ' {
						$eval-proc = Proc::Async.new: "perl", 'eval.pl', $<cmd>, :r, :w;
					}
					elsif $<lang> eq '!p6 ' {
						$eval-proc = Proc::Async.new: "perl6", '--setting=RESTRICTED', '-e', $<cmd>, :r, :w;
					}
					my ($stdout-result, $stderr-result);
					my Tap $eval-proc-stdout = $eval-proc.stdout.tap: $stdout-result ~= *;
					my Tap $eval-proc-stderr = $eval-proc.stderr.tap: $stderr-result ~= *;
					my Promise $eval-proc-promise;
					my $timeout-promise = Promise.in(4);
					$timeout-promise.then( { $eval-proc.print(chr 3) if $eval-proc-promise.status !~~ Kept } );
					start {
						try {
							$eval-proc-promise = $eval-proc.start;
							await $eval-proc-promise or $timeout-promise;
							$eval-proc.close-stdin;
							$eval-proc.result;
							CATCH { default { say $_.perl } };
						};
						put "OUT: `$stdout-result`\n\nERR: `$stderr-result`";
						#await $eval-proc-promise or $timeout-promise;
						return if $timeout-promise.status ~~ Kept;
							ansi-to-irc($stderr-result);
							my %replace-hash = "\n" => '␤', "\r" => '↵', "\t" => '↹';
							for %replace-hash.keys -> $key {
								$stdout-result ~~ s:g/$key/%replace-hash{$key}/ if $stdout-result;
								$stderr-result ~~ s:g/$key/%replace-hash{$key}/ if $stderr-result;
							}
							my $final-output;
							$final-output ~= "STDOUT«$stdout-result»" if $stdout-result;
							$final-output ~= "  " if $stdout-result and $stderr-result;
							$final-output ~= "STDERR«$stderr-result»" if $stderr-result;
							$.irc.send: :where($e.channel), :text($final-output);

					}
				}
			}

		}
		my $timer_4 = now;
		note "3->4: {$timer_4 - $timer_3}";
		# Do this after Text Substitution
		$history-file.add-history($e);

		# If any of the words we see are nicknames we've seen before, update the last time that
		# person was mentioned
		for $e.text.trans(';,:' => '').words { $chanevent-file.update-mentioned($e.nick) if $chanevent-file.nick-exists($_) }
		my $timer_5 = now;
		note "4->5: {$timer_5 - $timer_4}";

		if $e.text ~~ / ^ '!cmd ' (.+) / and $e.nick eq 'samcv' {
			my $cmd-out = qqx{$0};
			say $cmd-out;
			ansi-to-irc($cmd-out);
			$cmd-out ~~ s:g/\n/ /;
			$.irc.send: :where($e.channel), :text($cmd-out);
		}
		elsif $e.text ~~ / 'GMT' (['+'||'-'] \d+)? / {
			$.irc.send: :where($e.channel), :text("{$e.nick}: Please excuse my intrusion, but please refrain from using GMT as it is deprecated, use UTC{$0} instead.");
		}
		my $timer_6 = now;
		note "5->6: {$timer_6 - $timer_5}";

		start { markov-feed( $e.text ) }
		my $timer_7 = now;
		note "6->7: {$timer_7 - $timer_6}";

		if $!proc ~~ Proc::Async {
			if $!proc.started {
				$running = True if $promise.status == Planned;
			}
			else {
				$running = False;
			}
		}
		my $timer_8 = now;
		note "7->8: {$timer_8 - $timer_7}";

		if ! $running or $!said-filename.IO.modified > $!said-modified-time or $e.text ~~ /^'!RESET'$/ {
			$!said-modified-time = $!said-filename.IO.modified;
			if $running {
				note "trying to kill $!said-filename";
				$!proc.say("KILL");
				$!proc.close-stdin;
				$!proc.kill(9);
			}
			note "Starting $!said-filename";
			$!proc = Proc::Async.new( 'perl', $!said-filename, :w, :r );
			$!proc.stdout.lines.tap( {
					my $line = $_;
					say $line;
					if $line ~~ s/ ^ '%' // {
						say "Trying to print to {$e.channel} : $line";
						#$.irc.send: :where($_) :text($line) for .channels;
						$.irc.send: :where($e.channel), :text($line);
					}

			 } );
			 $!proc.stderr.tap( {
				 $*ERR.print($_);
			 } );
			 $promise = $!proc.start;
		}
		my $timer_9 = now;

		$!proc.print("{$e.channel} >$bot-nick\< \<{$e.nick}> {$e.text}\n");
		note "8->9: {$timer_9 - $timer_8}";

		$!event_file_supplier.emit( 0 );
		my $timer_10 = now;
		note "Total, 1->10: {$timer_10 - $timer_1}";
		$.NEXT;
	}
}
my %secs-per-unit = :years<15778800>, :months<1314900>, :days<43200>,
					:hours<3600>, :mins<60>, :secs<1>, :ms<0.001>;
sub from-secs ( $secs-since-epoch is copy ) is export  {
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
sub string-to-secs ( Str $string ) is export {
	my %secs-per-string = :years<15778800>, :year<15778800>, :months<1314900>,
	                      :month<1314900>, :weeks<302400>, :week<302400>, :days<43200>,
	                      :hours<3600>, :mins<60>, :minutes<60>, :minute<60>, :secs<1>,
	                      :seconds<1>, :second<1>,
	                      :ms<0.001>, :milliseconds<0.001>;
	say "string-to-secs got Str: [$string]";
	if $string ~~ / (\d+) ' '? (\S+) / {
		my $in-num = ~$0;
		my $in-unit = ~$1;
		say "in-num: [$in-num] in-unit: [$in-unit]";
		for %secs-per-string.kv -> $unit, $secs {
			say "checking unit: [$unit]";
			if $unit eq $in-unit {
				say "Unit [$unit]";
				return $secs * $in-num;
			}
		}
	}
	else {
		say "Didn't match regex";
		return Nil;
	}
}

sub format-time ( $time-since-epoch ) {
	return if $time-since-epoch == 0;
	my Str $tell_return;
	my $tell_time_diff = now.Rat - $time-since-epoch;
	my $sign = $tell_time_diff < 0 ?? "" !! "ago";
	$tell_time_diff .= abs;
	say $tell_time_diff;
	return irc-text('[Just now]', :color<teal>) if $tell_time_diff < 1;
	#return "[Just Now]" if $tell_time_diff < 1;
	my %time-hash = from-secs($tell_time_diff);
	$tell_return = '[';
	for %time-hash.keys -> $key {
		$tell_return ~= sprintf '%.2f', %time-hash{$key};
		$tell_return ~= " $key ";
	}
	$tell_return ~= "$sign]";
	return irc-text($tell_return, :color<teal> );
}

# vim: noet
