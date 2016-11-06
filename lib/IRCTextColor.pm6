use v6;
my %style_table =
	'bold'      => 2.chr,
	'italic'    => 29.chr,
	'underline' => 31.chr,
	'reset'     => 15.chr,
	'reverse'   => 22.chr,
	'color'     => 3.chr;
my %color_table =
	'white'       => '00',
	'black'       => '01',
	'blue'        => '02',
	'green'       => '03',
	'red'         => '04',
	'brown'       => '05',
	'purple'      => '06',
	'orange'      => '07',
	'yellow'      => '08',
	'light_green' => '09',
	'teal'        => '10',
	'light_cyan'  => '11',
	'light_blue'  => '12',
	'pink'        => '13',
	'grey'        => '14',
	'light_grey'  => '15';

sub irc-text ($text is copy, :$color? = 0, :$style? = 0) is export {
	given $color {
		if %color_table{$color} {
			$text = %style_table{'color'} ~ %color_table{$color} ~ $text ~ %style_table{'reset'};
		}
	}
	given $style {
		if %style_table{$style} {
			$text = %style_table{$style} ~ $text ~ %style_table{'reset'};
		}
	}
	return $text;
}

sub irc-style ($text is rw, :$color? = 0, :$style? = 0) is export {
	given $color {
		if %color_table{$color} {
			$text = %style_table{'color'} ~ %color_table{$color} ~ $text ~ %style_table{'reset'};
		}
	}
	given $style {
		if %style_table{$style} {
			$text = %style_table{$style} ~ $text ~ %style_table{'reset'};
		}
	}
	return $text;
}
