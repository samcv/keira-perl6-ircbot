use v6.c;
use IRC::Client;
use Text::Markov;
use Terminal::ANSIColor;
use JSON::Fast;
use WWW::Google::Time;
use IRCTextColor;
=head1 What
=para
A Perl 6+5 bot using the IRC::Client Perl 6 module

=head1 Description
=para
This is an IRC bot in Perl 5 and 6. It was originally only in Perl 5 but the core has now been rewriten
in Perl 6, and the rest is being ported over now.

class said2 does IRC::Client::Plugin {
	has $.said-filename = 'said.pl';
	has $.proc = Proc::Async.new( 'perl', $!said-filename, :w, :r );
	my $promise;
	my %chan-event;    # %chan-event{$e.nick}{join/part/quit/host/usermask}
	my %chan-mode;     # %chan-mode{$e.server.host}{channel}{time}{mode}{descriptor}
	my %curr-chanmode; # %curr-chanmode{$e.server.host}{$channel}{time}{mode}{descriptor}
	my %history;       # %history{$now}{text/nick/sed}
	my %op;            # %op{'nick'}{usermask/hostname}
	has %.strings = { 'unauthorized' => "Your nick/hostname/usermask did not match. You are not authorized to perform this action" };
	has $.last-saved-event = now;
	has $.last-saved-history = now;
	has $.last-saved-ban = now;
	has IO::Handle $!channel-event-fh;
	has Instant $!said-modified-time;
	has Supplier $.event_file_supplier = Supplier.new;
	has Supply $.event_file_supply = $!event_file_supplier.Supply;
	has Supply:U $.tick-supply;
	has Supply:D $.tick-supply-interval = $!tick-supply.interval(1);
	# Bans the mask from specified channel
	sub ban ( $e, $channel, $mask, $secs) {
		my $ban-for = now.Rat + $secs;
		%chan-mode{$e.server.host}{$channel}{$ban-for}{'-b'} = $mask;
		$e.irc.send-cmd: 'MODE', "{$e.channel} +b $mask", $e.server;
		$e.irc.send: :where($e.channel) :text("Banned for {format-time($ban-for)}");
	}
	sub unban ( $e, $channel, $mask) {
		$e.irc.send-cmd: 'MODE', "{$e.channel} -b $mask", $e.server;
	}
	sub give-ops ( $e, $channel, $nick) {
		$e.irc.send-cmd: 'MODE', "$channel +o $nick", $e.server;
	}
	sub take-ops ( $e, $channel, $nick) {
		$e.irc.send-cmd: 'MODE', "$channel -o $nick", $e.server;
	}

	sub kick ( $e, $channel, $user, $message ) {
		say "$channel $user $message";
		$e.irc.send-cmd: 'KICK', "$channel $user", ":$message", $e.server;
	}
	# Receives an object and checks that the sender is an op
	sub check-ops ( $e ) {
		if %op{$e.nick} {
			if $e.host eq %op{$e.nick}{'hostname'} and $e.usermask eq %op{$e.nick}{'usermask'} {
				return 1;
			}
		}
		return 0;
	}

	method irc-mode-channel ($e) {
		my @mode-pairs = $e.modes;
		my $server = $e.server;
		my $mode-type = @mode-pairs.shift;
		my $mode;
		$mode-type = $mode-type.key ~ $mode-type.value;
		for @mode-pairs -> $elem {
			$mode ~= $elem.value;
		}
		# %curr-chanmode{$e.server.host}{$channel}{time}{mode}{descriptor}
		say $mode; # descriptor
		say $mode-type; # +b
		#if %curr-chanmode
		#%curr-chanmode{$e.server.host}{$e.channel}{now.Rat}{$mode-type}{$mode}

		if $mode-type ~~ /'b'/ {
			my $user = $mode;
			$mode ~~ m/ ^ $<nick>=( \S+ ) '!' /;
			my $nick = $<nick>;
			$nick ~~ s:g/ (\S*)? '*' (\S*)?/'$0'\\S*'$1'/;
			$nick ~~ s/ '*' /\\S*/;
			say "nick regex: $nick";
			for %chan-event.keys -> $key {
				if $key ~~ /<$nick>/ {
				}
			}
		}

	}
	method irc-join ($e) {
		%chan-event{$e.nick}{'join'} = now.Rat;
		%chan-event{$e.nick}{'host'} = $e.host;
		%chan-event{$e.nick}{'usermask'} = $e.usermask;

		$!event_file_supplier.emit( 0 );
		Nil;
	}
	method irc-part ($e) {
		%chan-event{$e.nick}{'part'} = now.Rat;
		%chan-event{$e.nick}{'part-msg'} = $e.args;

		%chan-event{$e.nick}{'host'} = $e.host;
		%chan-event{$e.nick}{'usermask'} = $e.usermask;

		$!event_file_supplier.emit( 0 );
		Nil;
	}
	method irc-quit ($e) {
		%chan-event{$e.nick}{'quit'} = now.Rat;
		%chan-event{$e.nick}{'quit-msg'} = $e.args;

		%chan-event{$e.nick}{'host'} = $e.host;
		%chan-event{$e.nick}{'usermask'} = $e.usermask;
		$!event_file_supplier.emit( 0 );
		Nil;
	}
	method irc-connected ($e) {
		my Str $event-filename = $e.server.current-nick ~ '-event.json';
		my Str $event-filename-bak = $event-filename ~ '.bak';

		my Str $history-filename = $e.server.current-nick ~ '-history.json';
		my Str $history-filename-bak = $history-filename ~ '.bak';

		my Str $ops-filename = $e.server.current-nick ~ '-ops.json';
		my Str $ops-filename-bak = $ops-filename ~ '.bak';

		my Str $ban-filename = $e.server.current-nick ~ '-ban.json';
		my Str $ban-filename-bak = $ban-filename ~ '.bak';

		if ! %history {
			%history = load-file(%history, $history-filename, $e);
		}
		if ! %chan-event {
			%chan-event = load-file(%chan-event, $event-filename, $e);
		}
		if ! %op {
			%op = load-file(%op, $ops-filename, $e);
		}
		if ! %chan-mode {
			%chan-mode = load-file(%chan-mode, $ban-filename, $e);
		}
		my $ops-file-watch-supply = $ops-filename.IO.watch;
		multi write-file ( %data, $file-bak, $file ) {
			my $var = 0.Int;
			my $force = 1.Int;
			write-file(%data, $file-bak, $file, $var, $force);
		}
		multi write-file ( %data, $file-bak, $file, $last-saved is rw, Int $force ) {
			if now - $last-saved > 10 or !$last-saved.defined or $force {
				my $file-bak-io = IO::Path.new($file-bak);
				try {
					say colored("Trying to update $file data", 'blue');
					spurt $file-bak, to-json( %data );
					# from-json will throw an exception if it can't process the file
					# we just wrote
					from-json(slurp $file-bak);
					CATCH { .note }
				}
				$file-bak-io.copy($file) unless $!.defined;
				$last-saved = now;
			}
		}
		$.tick-supply-interval.tap( {
			for	$e.server.channels -> $channel {
				for %chan-mode{$e.server.host}{$channel}.keys -> $time {
					if $time < now {
						for  %chan-mode{$e.server.host}{$channel}{$time}.kv -> $mode, $descriptor {
							say "$channel $mode $descriptor";
							$.irc.send-cmd: 'MODE', "$channel $mode $descriptor", $e.server;
							%chan-mode{$e.server.host}{$channel}{$time}:delete;
						}
					}
				}
			}
		 } );
		$.event_file_supply.tap( -> $msg { write-file( %chan-event, $event-filename-bak, $event-filename, $!last-saved-event, $msg.Int ) } );
		$.event_file_supply.tap( -> $msg { write-file( %history, $history-filename-bak, $history-filename, $!last-saved-history, $msg.Int ) } );
		$.event_file_supply.tap( -> $msg { write-file( %chan-mode, $ban-filename-bak, $ban-filename, $!last-saved-ban, $msg.Int ) } );
		Nil;
	}
	method irc-privmsg-channel ($e) {
		my $bot-nick = $e.server.current-nick;
		my $now = now.Rat;
		my $timer_1 = now;
		%chan-event{$e.nick}{'spoke'} = $now;
		%chan-event{$e.nick}{'host'} = $e.host;
		%chan-event{$e.nick}{'usermask'} = $e.usermask;
		my $timer_2 = now;
		my $working;
		my $timer_3 = now;

		my $timer_4 = now;
		say "proc print: {$timer_4 - $timer_3}";
		say "Trying to write to $!said-filename : {$e.channel} >$bot-nick\< \<{$e.nick}> {$e.text}";
		if (^50).pick.not {
			start {
				my $mc = Text::Markov.new;
				for %history.keys -> $key {
					if %history{$key}{'text'} !~~ / ^ '!'/ {
						say %history{$key}{'text'};
						say qqw{ %history{$key}{'text'} };
						$mc.feed( qqw{ %history{$key}{'text'} } );
					}
				}
				my $markov-text = $mc.read(75);
				$markov-text ~~ s/'.'.*?$/./;
				$.irc.send: :where($e.channel) :text($mc.read(75));
			}
		}
		given $e.text {
			=head2 Text Substitution
			=para
			s/before/after/gi functionality. Use g or i at the end to make it global or case insensitive

			when m:i{ ^ 's/' (.+?) '/' (.*) '/'? } {
				my Str $before = $0.Str;
				my Str $after = $1.Str;
				# We need to do this to allow Perl 5/PCRE style regex's to work as expected in Perl 6
				# And make user input safe
				while $before ~~ /'[' .*? <( '-' )> .*? ']'/ {
					$before ~~ s:g/'[' .*? <( '-' )> .*? ']'/../;
				}
				for <- & ! " ' % = , ; : ~ ` @ { } \> \<>  ->  $old {
					$before ~~ s:g/$old/{"\\" ~ $old}/;
				}
				$before ~~ s:g/'#'/'#'/;
				$before ~~ s:g/ '$' .+ $ /\\\$/;
				$before ~~ s:g/'[' (.*?) ']'/<[$0]>/;
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
				for %history.sort.reverse -> $pair {
					my $sed-text = %history{$pair.key}{'text'};
					my $sed-nick = %history{$pair.key}{'nick'};
					my $was-sed = False;
					$was-sed  = %history{$pair.key}{'sed'} if %history{$pair.key}{'sed'};
					next if $sed-text ~~ m:i{ ^ 's/' };
					next if $sed-text ~~ m{ ^ '!' };
					if $sed-text ~~ m/<$before>/ {
						$sed-text ~~ s:g/<$before>/$after/ if $global;
						$sed-text ~~ s/<$before>/$after/ if ! $global;
						irc-style($sed-nick, :color<teal>);
						my $now = now.Rat;
						%history{$now}{'text'} = "<$sed-nick> $sed-text";
						%history{$now}{'nick'} = $bot-nick;
						%history{$now}{'sed'} = True;
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
			when /^'!derp'/ {
				start {
					my $mc = Text::Markov.new;
					for %history.keys -> $key {
						if %history{$key}{'text'} !~~ / ^ '!'/ {
							say %history{$key}{'text'};
							say qqw{ %history{$key}{'text'} };
							$mc.feed( qqw{ %history{$key}{'text'} } );
						}
					}
					my $markov-text = $mc.read(75);
					$markov-text ~~ s/'.'.*?$/./;
					$.irc.send: :where($e.channel) :text($mc.read(75));
				}
			}
			=head2 Seen
			=para
			Replys with the last time the specified user has spoke, joined, quit or parted.
			`Usage: !seen nickname`

			when /^'!seen ' $<nick>=(\S+)/ {
				my $seen-nick = ~$<nick>;
				last if ! %chan-event{$seen-nick};
				my $seen-time;
				for %chan-event{$seen-nick}.sort.reverse -> $pair {
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
				if %chan-event{$seen-nick}:exists {
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
			=head1 Operator Commands
			=para
			People who have been added as an operator in the 'botnick-ops.json' file will be allowed
			to perform the following commands if their nick, hostname and usermask match those
			in the file.

			=head2 Unban
			=para `Usage: !unban nick`

			when / ^ '!unban ' (\S+) ' '? (\S+)? / {
				my $ban-who = $0;
				my $ban-len = $1;
				check-ops($e);
				if check-ops($e) {
					unban($e, $e.channel, "$ban-who*!*@*");
				}
				else {
					$.irc.send: :where($e.channel), :text(%.strings<unauthorized>);
				}
			}
			=head2 Ban
			=para
			The specified user will be banned by 30 minutes at default. You can override this and
			set a specific number of seconds to ban for instead. The bot will automatically unban
			the person once this time period is up, as well as printing to the channel how long the
			user has been banned for.

			when / ^ '!ban ' (\S+) ' '? (\S+)? / {
				my $ban-who = $0;
				my $ban-len = $1;
				$ban-len = $ban-len > 0 ?? $ban-len !! 1800;
				if check-ops($e) {
					ban($e, $e.channel, "$ban-who*!*@*", $ban-len);
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
					give-ops($e, $e.channel, $op-who);
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
					take-ops($e, $e.channel, $op-who);
				}
				else {
					$.irc.send: :where($e.channel), :text(%.strings<unauthorized>);
				}
			}
			=head2 Kick
			=para Kicks the specified user from the channel. You are also allowed to specify a
			custom kickmessage as well. `Usage: !kick nickname` or `!kick nickname custom message`.

			when m{ ^ '!kick ' $<kick-who>=(\S+) ' '? $<message>=(.+)? } {
				if check-ops($e) {
					my $message = $<message> ?? $<message> !! "Better luck next time";
					kick( $e, $e.channel, $<kick-who>, $message );
				}
				else {
					$.irc.send: :where($e.channel), :text(%.strings<unauthorized>);
				}
			}

		}
		%history{$now}{'text'} = $e.text;
		%history{$now}{'nick'} = $e.nick;
		# If any of the words we see are nicknames we've seen before, update the last time that
		# person was mentioned
		for $e.text.trans(';,:' => '').words { %chan-event{$e.nick}{'mentioned'}{$_} = $now if %chan-event{$_}:exists }

		if $e.text ~~ /^'!cmd '(.+)/ and $e.nick eq 'samcv' {
			my $cmd-out = qqx{$0};
			say $cmd-out;
			ansi-to-irc($cmd-out);
			$cmd-out ~~ s:g/\n/ /;
			$.irc.send: :where($e.channel), :text($cmd-out);
		}
		=head2 Mentioned
		=para Gets the last time the specified person mentioned any users the bot knows about.
		=para `Usage: !mentioned nickname`

		elsif $e.text ~~ /^'!mentioned '(\S+)/ {
			my $temp_nick = $0;
			if %chan-event{$temp_nick}{'mentioned'}:exists {
				my $second = "$temp_nick mentioned, ";
				for %chan-event{$temp_nick}{'mentioned'}.sort(*.value).reverse -> $pair {
					$second ~= "{$pair.key}: {format-time($pair.value)} ";
				}
				$.irc.send: :where($e.nick), :text($second);
			}
		}
		=head2 Time
		=para Gets the current time in the specified location. Uses Google to do the lookups.
		=para `Usage !time Location`

		elsif $e.text ~~ /^'!time '(.*)/ {
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

		elsif $e.text ~~ /^'!p6 '(.+)/ {
			my $eval-proc = Proc::Async.new: "perl6", '--setting=RESTRICTED', '-e', $0, :r, :w;
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
		=head2 Perl 5 Eval
		=para Evaluates the requested Perl 5 code and returns the output of standard out
		and error messages.
		=para `Usage: !p my $var = "Hello Perl 5 World!\n"; print $var`

		# TODO try and combine both P5 and P6 into one function
		elsif $e.text ~~ /^'!p '(.+)/ {
			my $eval-proc = Proc::Async.new: "perl", 'eval.pl', $0, :r, :w;
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
		elsif $e.text ~~ /'GMT' (['+'||'-'] \d+)? / {
			$.irc.send: :where($e.channel), :text("{$e.nick}: Please excuse my intrusion, but please refrain from using GMT as it is deprecated, use UTC{$0} instead.");
		}
		# Remove old keys if history is bigger than 30 and divisible by 8
		#if %history.elems > 30 and %history.elems %% 8 {
		#	for %history.sort -> $pair {
		#		last if %history.elems <= 30;
		#		%history{$pair.key}:delete;
		#	}
		#}

		if $!proc ~~ Proc::Async { $working = $!proc.started } else { $working = False }
		if ! $working or $!said-filename.IO.modified > $!said-modified-time or $e.text ~~ /^'!RESET'$/ {
			$!said-modified-time = $!said-filename.IO.modified;
			if $!proc.started {
				note "trying to kill $!said-filename";
				$!proc.say("KILL");
				$!proc.close-stdin;
				$!proc.kill(9);
				#try { $promise.result; CATCH { note "$!said-filename exited incorrectly! THIS IS BAD"; $!proc = Nil; } }
			}
			note "Starting $!said-filename";
			$!proc = Proc::Async.new( 'perl', $!said-filename, :w, :r );
			$!proc.stdout.lines.tap( {
					my $line = $_;
					say $line;
					if $line ~~ s/^\%// {
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

		$!proc.print("{$e.channel} >$bot-nick\< \<{$e.nick}> {$e.text}\n");
		$!event_file_supplier.emit( 0 );
		my $timer_10 = now;
		say "took this many seconds: {$timer_10 - $timer_1}";
		Nil;
	}
}

sub convert-time ( $secs-since-epoch is copy ) is export  {
	my %time-hash;
	my %secs-per-unit = :years<15778800>, :months<1314900>, :days<43200>,
	                    :hours<3600>, :mins<60>, :secs<1>, :ms<0.001>;
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
	my $tell_time_diff = now.Rat - $time-since-epoch;
	my $sign = $tell_time_diff < 0 ?? "" !! "ago";
	$tell_time_diff .= abs;
	say $tell_time_diff;
	return irc-text('[Just now]', :color<teal>) if $tell_time_diff < 1;
	#return "[Just Now]" if $tell_time_diff < 1;
	my %time-hash = convert-time($tell_time_diff);
	$tell_return = '[';
	for %time-hash.keys -> $key {
		$tell_return ~= sprintf '%.2f', %time-hash{$key};
		$tell_return ~= " $key ";
	}
	$tell_return ~= "$sign]";
	return irc-text($tell_return, :color<teal> );
}
sub to-sec ( $string ) {
}


sub load-file ( \hash, Str $filename, $e ) is rw {
	my $hash := hash;
	if $filename.IO.e {
		say "Trying to load $filename";
		$hash := from-json( slurp $filename );
		say "$filename DATA:" if $e.irc.debug.Bool;
		say $hash if $e.irc.debug.Bool;
	}
	else {
		say "Cannot find $filename";
	}
	$hash;
}
# vim: noet
