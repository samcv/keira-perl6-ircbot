#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use feature 'unicode_strings';
use English;
use Exporter qw(import);
our @EXPORT_OK = qw(text_style);

my %style_table = (
	bold      => chr 2,
	italic    => chr 29,
	underline => chr 31,
	reset     => chr 15,
	reverse   => chr 22,
	color     => chr 3,
);
my %color_table = (
	white       => '00',
	black       => '01',
	blue        => '02',
	green       => '03',
	red         => '04',
	brown       => '05',
	purple      => '06',
	orange      => '07',
	yellow      => '08',
	light_green => '09',
	teal        => '10',
	light_cyan  => '11',
	light_blue  => '12',
	pink        => '13',
	grey        => '14',
	light_grey  => '15',
);

sub text_style {
	my ( $string, $effect, $foreground, $background ) = @_;

	if ( defined $background and defined $foreground ) {
		$string
			= $style_table{color}
			. $color_table{$foreground} . q(,)
			. $color_table{$background}
			. $string
			. $style_table{reset};
	}
	elsif ( defined $foreground ) {
		$string = $style_table{color} . $color_table{$foreground} . $string . $style_table{color};
	}
	if ( defined $effect ) {
		$string = $style_table{$effect} . $string . $style_table{$effect};
	}
	$string =~ s/$style_table{reset}+/$style_table{reset}/g;
	$string =~ s/$style_table{reset}+/$style_table{color}/g;

	return $string;
}
