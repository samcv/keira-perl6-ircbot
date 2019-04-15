use v6.c;
# Ecosystem Modules
use IRC::Client;
use Text::Markov;
use Terminal::ANSIColor;
# My Modules
use P5-to-P6-Regex;
use IRC::TextColor;
use ConvertBases;
use PerlEval;
use classes;
use format-time;
=head1 What
=para
A Perl 6+5 bot using the IRC::Client Perl 6 module

=head1 Description
=para
This is an IRC bot in Perl 5 and 6. It was originally only in Perl 5 but the core has now been rewriten
in Perl 6, and the rest is being ported over now.

my $debug = True;

class Keira does IRC::Client::Plugin {
	has Str $.said-filename = 'said.pl';
	has Proc::Async $.proc = Proc::Async.new( 'perl', $!said-filename, :w, :r );
	my $promise;
	# Describes planned future events. Mode can be '-b' to unban after a specified amount of time.
	# If mode is `msg` the descriptor will be their nickname, whose value is set to the message.
	my %ops;            # %ops{'nick'}{usermask/hostname}
	has %.strings = { 'unauthorized' => "Your nick/hostname/usermask did not match. You are not authorized to perform this action" };
	state history-class $history-file;
	state chanevent-class $chanevent-file;
	state chanmode-class $chanmode-file;
	state perlbot-file $ops-file;

	has IO::Handle $!channel-event-fh;
	has Instant $!said-modified-time;
	has Supplier $.event_file_supplier = Supplier.new;
	has Supply $.event_file_supply = $!event_file_supplier.Supply;
	has Supply:U $.tick-supply;
	has Supply:D $.tick-supply-interval = $!tick-supply.interval(1);
	state $markov;
	state $markov-lock = Lock.new;
	sub set-mode ( $e, Str $argument, Str :$mode) {
		$e.irc.send-cmd: 'MODE', $e.channel, $mode, $argument, :server($e.server);
	}
	# Bans the mask from specified channel
	sub ban ( $e, Str $mask, $secs) {
		my $ban-for = now.Rat + $secs;
		$chanmode-file.schedule-unban($e, $ban-for, $mask);
		set-mode($e, :mode<+b>, $mask);
		$e.irc.send: :where($e.channel) :text("Banned for {format-time($ban-for)}");
	}
	sub unban ( $e, Str $mask) {
		set-mode($e, :mode<-b>, $mask);
	}
	sub give-ops ( $e, Str $nick) {
		set-mode($e, :mode<+o>, $nick);
	}
	sub take-ops ( $e, Str $nick) {
		set-mode($e, :mode<-o>, $nick);
	}
	sub kick ( $e, Str $user, Str $message ) {
		$e.irc.send-cmd: 'KICK', $e.channel, $user, $message, :server($e.server);
	}
	sub topic ( $e, Str $topic ) {
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
		if $string !~~ / ^ '!'|'s/'|[\S': '] / {
			$string ~~ s/$/ /;
			$string ~~ s:g/(\S+) ('.'|'!'|':'|';'|',') ' '/ $0 $1 /;
			$markov-lock.protect( {	$markov.feed( $string.words ) if $markov.isa(Text::Markov) } );
		}
	}
	method irc-mode-channel ($e) {
		my @mode-pairs = $e.modes;
		my $server = $e.server;
		my $mode-type = @mode-pairs.shift;
		$mode-type = $mode-type.key ~ $mode-type.value;
		my $mode-descriptor = @mode-pairs.join;
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
		if ! $ops-file {
			$ops-file = ops-class.new( filename => $e.server.current-nick ~ '-ops.json' );
			$ops-file.load;
			#$ops-file.ops-file-watch;
			%ops = $ops-file.get-hash;
		}
		if ! $chanmode-file {
			$chanmode-file = chanmode-class.new( filename => $e.server.current-nick ~ '-ban.json' );
			$chanmode-file.load;
		}
		$.tick-supply-interval.tap( {
			if $_ %% 60 {
				send-ping($e);
			}
			my $chanmode = $chanmode-file.mode-schedule($e);
			$.irc.send-cmd: 'MODE', $chanmode, $e.server if $chanmode;
		} );
		$.event_file_supply.act( -> $msg {
			state $last-saved-time;
			if $last-saved-time.defined.not {
				note "last saved time not defined so setting now";
				$last-saved-time = now;
			}
			if now - $last-saved-time < 100 and $msg <= 0 {
				say "I think it's been less than 100 secs or got msg <= 0";
				say now - $last-saved-time;
				say "message $msg";
				last;
			}
			else {
				say "It's been {now - $last-saved-time} since saving. Trying to save now";
			}
			$last-saved-time = now;
			note "Received message $msg for saving" if $debug;
			state @write-promises;
			for @write-promises -> $p {
				await $p if $p ~~ Promise:D;
			}
			@write-promises = ( );
			push @write-promises, $chanevent-file.save($msg.Int);
			push @write-promises, $history-file.save($msg.Int);
			push @write-promises, $chanmode-file.save($msg.Int);
			if $msg >= 3 {
				note "Waiting for files to save…";
				await Promise.allof(@write-promises);
				$.irc.quit;
			}
		} );
		signal(SIGINT).tap( {
			note "Trying to quit. Received SIGINT";
			$!event_file_supplier.emit( 3 )
		} );
		my $p = start {
			$markov-lock.protect( { $markov = Text::Markov.new: :order<new> } );
			for $history-file.get-history».values -> $value {
				markov-feed( $value{'text'} );
			}
		}
		$p.then( { note "Done feeding Markov Chain" if $p.status != Broken } );
		$.NEXT;
	}
	sub send-markov-to-chan ($e) {
		say "in send markov";
		my $m-prom = start { markov(75) }
		$m-prom.then( {
			say "trying to send markov";
			$e.irc.send: :where($e.channel) :text($m-prom.result) if $m-prom.status == Kept } );
	}
	method irc-privmsg-channel ($e) {
		my $unrec-time = "Unrecognized time format. Use X ms, sec(s), second(s), min(s), minutes(s), hour(s), week(s), month(s) or year(s)";
		my $bot-nick = $e.server.current-nick;
		my $now = now.Rat;
		my $timer_1 = now;
		$chanevent-file.update-event($e);
		my $running;
		my $tell = $chanmode-file.tell-nick($e);
		if $tell {
			say $tell;
			$.irc.send: :where($tell<where>) :text($tell<text> );
		}
		my $timer_2 = now;
		note "1->2: {$timer_2 - $timer_1}" if $debug;
		if (^50).pick.not {
			send-markov-to-chan($e);
		}
		my $timer_3 = now;
		note "2->3: {$timer_3 - $timer_2}" if $debug;
		given $e.text {
			when m/ ^ \s* '[' $<trigger-text>=(.*) ']' \s* $ / {
				my $trigger-text = $<trigger-text>.trim.uc;
				$trigger-text = $trigger-text.substr(0, *-2) ~ "ING"
					if $trigger-text.ends-with('ED') and 3 < $trigger-text.chars;
				my $all = False;
				my $all-color = 'white';
				my $all-bgcolor = 'red';
				my $side-color = 'red';
				my $side-bgcolor = 'white';
				my $out;
				if $all {
					$out = irc-style-text("[" ~ "$trigger-text INTENSIFIES" ~ "]", :color($all-color), :bgcolor($all-bgcolor));
				}
				else {
					$out = irc-style-text("[", :color($side-color), :bgcolor($side-bgcolor)) ~
					irc-style-text("$trigger-text ", :color($all-color), :bgcolor($all-bgcolor)) ~
					irc-style-text(" INTENSIFIES", :color($side-color), :bgcolor($side-bgcolor)) ~
					irc-style-text("]", :color($side-bgcolor), :bgcolor($side-color));
				}
				$.irc.send: :where($e.channel) :text($out);
			}
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
				note "Before: {colored($before.Str, 'green')} After: {colored($after.Str, 'green')}" if $debug;
				note "Options: {colored($options.Str, 'green')}" if $options and $debug;
				my ( $global, $case )  = False xx 2;
				$global = ($options ~~ / g /).Bool if $options.defined;
				$case = ($options ~~ / i /).Bool if $options.defined;
				say "Global is $global Case is $case";
				$before = ':i ' ~ $before if $case;
				start {
					my %return;
					for $history-file.get-history -> $value {
						state $i++;
						#last if $i > 30;
						my Str $sed-text = $value.value<text>;
						my Str $sed-nick = $value.value<nick>;
						my $was-sed = $value{'sed'} ?? True !! False;
						next if $sed-text ~~ m:i{ ^ 's/' };
						next if $sed-text ~~ m{ ^ '!' };
						if $sed-text ~~ m/<$before>/ {
							$global ?? $sed-text ~~ s:g/<$before>/$after/ !! $sed-text ~~ s/<$before>/$after/;
							$sed-nick = irc-style-text($sed-nick, :color<teal>);
							%return =  text => $sed-text, time => now.Rat, nick => $sed-nick, was-sed => $was-sed;
							last;
						}
					}
					if %return {
						my %sed-hash := %return;
						my $sed-nick = %sed-hash<nick>;
						my $sed-text = %sed-hash<text>;
						my $time = %sed-hash<time>;
						$history-file.add-entry( $time, text => "<$sed-nick> $sed-text", nick => $bot-nick, sed => True );
						if ! %sed-hash<was-sed> {
							$.irc.send: :where($e.channel) :text("<$sed-nick> $sed-text");

						}
						else {
							$.irc.send: :where($e.channel) :text("$sed-text");
						}
					}
				};
			}
		}
		if $e.text.starts-with('!') {
			given $e.text {
				when / ^ '!g ' (.*) / {
					use URI::Encode;
					my $url = "http://www.google.com/search?q={ uri_decode($0.Str) }&btnI";
					$!proc.print("{$e.channel} >$bot-nick\< \<{$e.nick}>  $url\n");
				}
				when / ^ '!derp' / {
					send-markov-to-chan($e);
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
						$seen-time ~= irc-style-text($pair.key.tc, :style<underline>) ~ ': ' ~ $second ~ ' ';
					}
					if $chanevent-file.nick-exists($seen-nick) {
						$seen-nick = irc-style-text($seen-nick, :color<blue>, :style<bold>);
						$.irc.send: :where($e.channel), :text("$seen-nick $seen-time");
					}
				}
				=head2 Saving Channel Event Data
				=para The command `!SAVE` will cause the channel event data and history file to be saved.
				Normally it will save when the data changes in memory provided it hasn't already saved
				within the last 60 seconds

				when /^'!SAVE'/ {
					$!event_file_supplier.emit( 1 );
				}
				=head2 Tell
				=para Syntax: `!tell nickname message` or `!tell nickname in 10 minutes message`
				=para Will tell the specified nickname the message the next time they speak in channel

				when / ^ '!tell ' $<nick>=(\S+) ' in ' $<time>=(\d+) ' ' $<units>=(\S+) ' '? $<message>=(.*) / {
					say "Nick [{$<nick>}] Units [{$<units>}] Time [{$<time>}] Message [{$<message>}]";
					if $chanevent-file.nick-exists(~$<nick>) {
						my $message = ~$<message>;
						my $got = string-to-secs("$<time> $<units>");
						if !$got or $<nick> eq 'in' {
							$.irc.send: :where($e.channel), :text("Syntax: !tell nick message or !tell nick in 10 units $unrec-time");
							last;
						}
						# If we know about this person set it
						$chanmode-file.schedule-message( $e, :message($message), :to(~$<nick>), :when(now.Rat + $got) );

						$.irc.send: :where($e.channel), :text("{$e.nick}: I will relay the message to {$<nick>}");
					}
					else {
						$.irc.send: :where($e.channel), :text("{e.nick}: I have never seen this person before");
					}
				}
				when / ^ '!tell ' $<nick>=(\S+) ' '$<message>=(.*) / {
					say "Nick [{$<nick>}] Message [{$<message>}]";
					if $chanevent-file.nick-exists(~$<nick>) {
						$chanmode-file.schedule-message( $e, :message(~$<message>), :to(~$<nick>) );
						$.irc.send: :where($e.channel), :text("{$e.nick}: I will relay the message to {$<nick>}");
					}
					else {
						$.irc.send: :where($e.channel), :text("{e.nick}: I have never seen this person before");
					}
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
						my $op-who = $0.defined ?? ~$0 !! $e.nick;
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
						kick( $e, ~$<kick-who>, $message );
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
						topic($e, ~$<topic>);
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
					$.irc.send: :where($e.channel), :text(~$<torev>.flip);
				}
				when / ^ '!uc ' $<touc>=(.*) / {
					$.irc.send: :where($e.channel), :text(~$<touc>.uc);
				}
				when / ^ '!lc ' $<tolc>=(.*) / {
					$.irc.send: :where($e.channel), :text(~$<tolc>.lc);
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
				=head2 Perl 6 Eval
				=para Evaluates the requested Perl 6 code and returns the output of standard out
				and error messages.
				=para `Usage: !p6 my $var = "Hello Perl 6 World!"; say $var`

				=head2 Perl 5 Eval
				=para Evaluates the requested Perl 5 code and returns the output of standard out
				and error messages.
				=para `Usage: !p my $var = "Hello Perl 5 World!\n"; print $var`

				when / ^ '!' $<lang>=('p'|'p6') ' ' $<cmd>=(.+) / {
					my $lang = $<lang> eq 'p' ?? 'perl' !! 'perl6';
					my $cmd = ~$<cmd>;
					my $e-prom = start {
						my $result = perl-eval( :lang($lang), :cmd($cmd) );
						$.irc.send: :where($e.channel), :text( $result )
					}
					#$e-prom.then( {
					#	$.irc.send: :where($e.channel), :text( $e-prom.result ) unless $e-prom == Broken;
					#} );
				}
			}

		}
		my $timer_4 = now;
		note "3->4: {$timer_4 - $timer_3}" if $debug;
		# Do this after Text Substitution
		$history-file.add-history($e);

		# If any of the words we see are nicknames we've seen before, update the last time that
		# person was mentioned
		for $e.text.trans(';,:' => '').words { $chanevent-file.update-mentioned($e.nick) if $chanevent-file.nick-exists($_) }
		my $timer_5 = now;
		note "4->5: {$timer_5 - $timer_4}" if $debug;

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
		note "5->6: {$timer_6 - $timer_5}" if $debug;

		start { markov-feed( $e.text ) }
		my $timer_7 = now;
		note "6->7: {$timer_7 - $timer_6}" if $debug;

		if $!proc ~~ Proc::Async {
			if $!proc.started {
				$running = True if $promise.status == Planned;
			}
			else {
				$running = False;
			}
		}
		my $timer_8 = now;
		note "7->8: {$timer_8 - $timer_7}" if $debug;

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
			$!proc.stdout.lines.tap( -> $line is copy {
					if $line ~~ s/ ^ '%' // {
						say "Trying to print to {$e.channel} : $line" if $debug;
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
		note "8->9: {$timer_9 - $timer_8}" if $debug;

		$!event_file_supplier.emit( 0 );
		my $timer_10 = now;
		note "Total, 1->10: {$timer_10 - $timer_1}";
		$.NEXT;
	}
}

# vim: noet
