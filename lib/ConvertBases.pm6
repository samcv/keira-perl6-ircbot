use v6;
sub convert-bases ( Str $string, Str :$from, Str :$to ) returns Str is export {
	my @nums;
	my %mapping = :decimal<10>, :dec<10>, :binary<2>, :bin<2>, :octal<8>, :oct<8>, :hexadecimal<16>, :hex<16>;
	if %mapping{$from}:exists {
		@nums = split( ' ', $string);
		try { for ^@nums.elems { @nums[$_] = UNBASE(%mapping{$from}, @nums[$_] ) }; CATCH { return } }
	}
	elsif $from eq 'uni'|'unicode' {
		@nums = $string.ords;
	}
	my $output;
	given $to {
		when 'uni'|'unicode' {
			$output = @nums.chrs;
		}
		when 'decimal'|'dec' {
			$output = @nums.join(' ');
			$output .= trim;
		}
		when 'hexadecimal'|'hex' {
			for @nums { $output ~= sprintf("%x ", $_) }
			$output .= trim;
		}
		when 'octal'|'oct' {
			for @nums { $output ~= sprintf("%o ", $_) }
			$output .= trim;
		}
		when 'binary'|'bin' {
			for @nums { $output ~= sprintf("%b ", $_) }
			$output .= trim;
		}
	}
	$output;
}
# vim: noet
