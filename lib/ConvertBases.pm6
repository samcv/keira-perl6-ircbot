use v6;
sub convert-bases ( Str $string, Str :$from, Str :$to ) returns Str is export {
	say $string;
	my @nums;
	my %mapping = :decimal<10>, :dec<10>, :binary<2>, :bin<2>, :octal<8>, :oct<8>, :hexadecimal<16>, :hex<16>;
	say %mapping.perl;
	if %mapping{$from}:exists {
		say "it exists";
		@nums = split( ' ', $string);
		try { for ^@nums.elems { @nums[$_] = UNBASE(%mapping{$from}, @nums[$_] ) }; CATCH { return } }
	}
	elsif $from eq 'uni'|'unicode' {
		@nums = $string.ords;
	}
	my $output;
	given $to {
		say $to;
		when 'uni'|'unicode' {
			say 'u';
			$output = @nums.chrs;
		}
		when 'decimal'|'dec' {
			$output = @nums.join(' ');
		}
		when 'hexadecimal'|'hex' {
			for @nums { $output ~= sprintf("%x ", $_) }
		}
		when 'octal'|'oct' {
			for @nums { $output ~= sprintf("%o ", $_) }
		}
		when 'binary'|'bin' {
			for @nums { $output ~= sprintf("%b ", $_) }
		}
	}
	$output;
}
# vim: noet

#sub MAIN ( Str $option, Str $string ) {
#	$option ~~ / $<from>=(\S+) 2 $<to>=(\S+) /;
#	say convert-bases(~$string, :from(~$<from>), :to(~$<to>));
#}
