use IRC::Client::Message;
use JSON::Tiny;
use format-time;
my role perlbot-file is export {
	has Str $.filename;
	has Str $!filename-bak = $!filename ~ '.bak';
	has $!file-bak-io = IO::Path.new($!filename-bak);
	has %!hash;
	has $!last-saved = 0;
	method save ( $force? ) {
		if now - $!last-saved > 100 or $force {
			my Promise $promise = start { to-json(%!hash) }
			$promise.then( {
				if $promise.status == Kept {
					$!file-bak-io.spurt($promise.result);
					$!file-bak-io.copy($.filename);
					$!last-saved = now;
				}
				else {
					note $promise.result;
				}
			} );
			return $promise;
		}
		Nil;
	}

	method load {
		if $.filename.IO.e {
			say "Trying to load $.filename";
			my Promise $promise = start { from-json(slurp $.filename) }
			$promise.then( {
				if $promise == Kept {
					my %hash = $promise.result;
					%!hash = %hash;
				}
			} );
			return $promise;
		}
		else {
			say "Cannot find $.filename";
		}
		False;
	}
	method get-hash {
		%!hash;
	}
	method set-hash ( %hash ) {
		%!hash = %hash;
	}
}
# %ops{'nick'}{usermask/hostname}
my class ops-class does perlbot-file is export {
	#method ops-file-watch {
	#	$.filename.IO.watch-path.act(
	#}
	method has-ops ( $e ) {
		if $e.host eq %!hash{$e.nick}{'hostname'} and %!hash.usermask eq %!hash{$e.nick}{'usermask'} {
			return True;
		}
		False;
	}
}
# %!hash{$e.server.host}{channel}{time}{mode}{descriptor}
my class chanmode-class does perlbot-file is export {
	method tell-nick ( IRC::Client::Message $e ) {
		say "Calling tell-nick";
		say %!hash;
		for	$e.server.channels -> $channel {
			say $channel;
			for %!hash{$e.server.host}{$channel}.keys -> $time {
				if $time < now {
					say $time;
					for  %!hash{$e.server.host}{$channel}{$time}.kv -> $mode, $descriptor {

						say "Channel: [$channel] Mode: [$mode] Descriptor: [$descriptor]";
						if $mode eq 'tell' {
							for %!hash{$e.server.host}{$channel}{$time}{'tell'} -> %values {
								last if %values<to> ne $e.nick;
								%values.gist.say;
								%values<message>.say;
								say "trying to sendmessage";
								my $formated = "{%values<to>}: {%values<from>} said, {%values<message>} " ~ format-time(%values<when>);
								%!hash{$e.server.host}{$channel}{$time}:delete;

								return %{'where' => $channel, 'text' => $formated};
							}
						}
					}
				}
			}
		}
	}
	method schedule-message ( $e, Str :$message, Str :$to, Rat :$when = now.Rat ) {
		%!hash{$e.server.host}{$e.channel}{$when}{'tell'}{'from'} = $e.nick;
		%!hash{$e.server.host}{$e.channel}{$when}{'tell'}{'to'} = $to;
		%!hash{$e.server.host}{$e.channel}{$when}{'tell'}{'message'} = $message;
		%!hash{$e.server.host}{$e.channel}{$when}{'tell'}{'when'} = now.Rat;
	}
	method schedule-unban ( $e, $ban-for, $mask ) {
		%!hash{$e.server.host}{$e.channel}{$ban-for}{'-b'} = $mask;
	}
	method mode-schedule ( $e ) {
		for	$e.server.channels -> $channel {
			for %!hash{$e.server.host}{$channel}.keys -> $time {
				if $time < now {
					for  %!hash{$e.server.host}{$channel}{$time}.kv -> $mode, $descriptor {
						#say "Channel: [$channel] Mode: [$mode] Descriptor: [$descriptor]";
						if $mode ~~ / ^ '-'|'+' / {
							%!hash{$e.server.host}{$channel}{$time}:delete;
							return "$channel $mode $descriptor";
						}
					}
				}
			}
		}
	}

	method event-to-do ( $e ) {
		my @list;
		for	$e.server.channels -> $channel {
			for %!hash{$e.server.host}{$channel}.keys -> $time {
				for  %!hash{$e.server.host}{$channel}{$time}.kv -> $mode, $descriptor {
					push @list, mode => $mode, descriptor => $descriptor;
				}
			}
		}
		@list;
	}

}
my class history-class does perlbot-file is export {
	method add-history ( IRC::Client::Message $e ) {
		my $now = now;
		%!hash{$now}{'text'} = $e.text;
		%!hash{$now}{'nick'} = $e.nick;
	}
	method add-entry ( $now, Str :$text, Str :$nick, Bool :$sed = False ) {
		%!hash{$now} = text => $text, nick => $nick, sed => $sed;
	}
}
my class chanevent-class does perlbot-file is export {
	#  %chan-event{$e.nick}{join/part/quit/host/usermask}
	method get-nick-event ( Str $nick ) {
		%!hash{$nick} if %!hash{$nick};
	}
	method update-mentioned ( Str $nick ) {
		%!hash{$nick}{'mentioned'} = now.Rat;
	}
	multi method update-event ( IRC::Client::Message::Part $e ) {
		%!hash{$e.nick}{'part'} = now.Rat;
		%!hash{$e.nick}{'part-msg'} = $e.args;

		%!hash{$e.nick}{'host'} = $e.host;
		%!hash{$e.nick}{'usermask'} = $e.usermask;
	}
	multi method update-event ( IRC::Client::Message::Quit $e ) {
		%!hash{$e.nick}{'quit'} = now.Rat;
		%!hash{$e.nick}{'quit-msg'} = $e.args;

		%!hash{$e.nick}{'host'} = $e.host;
		%!hash{$e.nick}{'usermask'} = $e.usermask;
	}

	multi method update-event ( IRC::Client::Message::Join $e ) {
		%!hash{$e.nick}{'join'} = now.Rat;
		%!hash{$e.nick}{'host'} = $e.host;
		%!hash{$e.nick}{'usermask'} = $e.usermask;
	}

	multi method update-event ( $e ) {
		%!hash{$e.nick}{'quit'} = now.Rat;
		%!hash{$e.nick}{'quit-msg'} = $e.args;

		%!hash{$e.nick}{'host'} = $e.host;
		%!hash{$e.nick}{'usermask'} = $e.usermask;
	}
	multi method update-event ( IRC::Client::Message::Mode::Channel $e ) {
		...
	}
	multi method update-event ( IRC::Client::Message::Privmsg::Channel $e ) {
		%!hash{$e.nick}{'spoke'} = now.Rat;
		%!hash{$e.nick}{'host'} = $e.host;
		%!hash{$e.nick}{'usermask'} = $e.usermask;
	}
	method nick-exists ( Str $nick ) {
		%!hash{$nick}.Bool;
	}

}
