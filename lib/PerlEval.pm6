use v6;
use IRC::TextColor;
sub perl-eval ( Str :$lang, Str :$cmd ) returns Str is export {
	my $eval-proc;
	say $lang;
	say $cmd;
	if $lang eq 'perl' {
		$eval-proc = Proc::Async.new: "perl", 'eval.pl', $cmd, :r, :w;
	}
	elsif $lang eq 'perl6' {
		$eval-proc = Proc::Async.new: "perl6", '--setting=RESTRICTED', '-e', $cmd, :r, :w;
	}
	else {
		return Nil;
	}
	my ($stdout-result, $stderr-result);
	my Tap $eval-proc-stdout = $eval-proc.stdout.tap: $stdout-result ~= *;
	my Tap $eval-proc-stderr = $eval-proc.stderr.tap: $stderr-result ~= *;
	my Promise $eval-proc-promise;
	my $timeout-promise = Promise.in(4);
	$timeout-promise.then( { $eval-proc.print(chr 3) if $eval-proc-promise.status !~~ Kept } );
	try {
		$eval-proc-promise = $eval-proc.start;
		await Promise.anyof($eval-proc-promise, $timeout-promise);
		$eval-proc.close-stdin;
		$eval-proc.result;
		CATCH { default { #`( say $_.perl ) } };
	};
	return Nil if $timeout-promise.status ~~ Kept;
		$stderr-result = ansi-to-irc($stderr-result) if $stderr-result;
		$stdout-result = ansi-to-irc($stdout-result) if $stdout-result;
		my %replace-hash = "\n" => '␤', "\r" => '↵', "\t" => '↹';
		for %replace-hash.keys -> $key {
			$stdout-result ~~ s:g/$key/%replace-hash{$key}/ if $stdout-result;
			$stderr-result ~~ s:g/$key/%replace-hash{$key}/ if $stderr-result;
		}
		my $final-output;
		$final-output ~= "STDOUT«$stdout-result»" if $stdout-result;
		$final-output ~= "  " if $stdout-result and $stderr-result;
		$final-output ~= "STDERR«$stderr-result»" if $stderr-result;
		say $final-output;
		return $final-output;

}
