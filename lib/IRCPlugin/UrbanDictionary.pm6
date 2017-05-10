use v6;
use IRC::Client;
use Inline::Perl5;
use WebService::UrbanDictionary:from<Perl5>;
# My Modules
use IRC::TextColor;

class Urban-Dictionary does IRC::Client::Plugin {
	has $.max-length = 250;
	method irc-privmsg-channel ($e) {
		given $e.text {
			when / ^ '!ud ' (.*) / {
				my $ud-request = $0.trim;
				start {
					say "[$ud-request]";
					my $ud = WebService::UrbanDictionary.new;
					my $def = $ud.request($ud-request).definitions[0];
					my $definition = $def.definition;
					my $example = $def.example;
					#$example ~~ s:g/\n/ /;
					#$definition ~~ s:g/\n/ /;
					$example ~~ s:g/<[ \x[00]..\x[1F] ]>//;
					$definition ~~ s:g/<[ \x[00]..\x[1F] ]>//;
					$example ~~ s:g/\s+/ /;
					$definition ~~ s:g/\s+/ /;
					$example .= subst(0, $.max-length);
					$definition .= subst(0, $.max-length);

					my $one-line = irc-style-text(:style<bold>, "{$def.word}: ") ~ $definition ~ ' ' ~ irc-style-text(:style<italic>, $example);
					if $one-line.chars > 300 {
						my $first-line = irc-style-text(:style<bold>, "{$def.word}: ") ~ $definition;
						my $second-line = irc-style-text(:style<italic>, $example);
						$.irc.send: :where($e.channel) :text( $first-line );
						sleep 0.5;
						$.irc.send: :where($e.channel) :text( $second-line );
					}
					else {
						$.irc.send: :where($e.channel) :text( $one-line );
					}
				}
			}
		}
		Nil;
	}
}
