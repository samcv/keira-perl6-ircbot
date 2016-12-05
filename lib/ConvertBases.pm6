use v6;
sub convert-bases ( Str $string, Str :$from, Str :$to ) returns Str is export {
	my @nums;
	my %mapping = :decimal<10>, :dec<10>, :binary<2>, :bin<2>, :octal<8>, :oct<8>, :hexadecimal<16>, :hex<16>;
	if %mapping{$from}:exists {
		@nums = split( ' ', $string);
		try { for ^@nums.elems { @nums[$_] = UNBASE %mapping{$from}, @nums[$_] }; CATCH { return } }
	}
	elsif $from eq 'uni'|'unicode' {
		@nums = $string.ords;
	}
	my $output;
	my %hash = bin => 2, binary => 2, oct => 8, octal => 8, dec => 10, decimal => 10, hex => 16, hexadecimal => 16;

	if %hash{$to} {
		for @nums { $output ~= sprintf "%s ", $_.base(%hash{$to}) }
		$output .= trim;
	}
	elsif $to eq 'uni'|'unicode' {
		$output = @nums.chrs;
	}
	$output;
}
# vim: noet
