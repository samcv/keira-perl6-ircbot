use v6;
# My Modules
use IRC::TextColor;
my %secs-per-unit = :years<15778800>, :months<1314900>, :days<43200>,
					:hours<3600>, :mins<60>, :secs<1>, :ms<0.001>;
sub from-secs ( $secs-since-epoch is copy ) is export  {
	my %time-hash;
	for %secs-per-unit.sort(*.value).reverse -> $pair {
		if $secs-since-epoch >= $pair.value {
			%time-hash{$pair.key} = $secs-since-epoch / $pair.value;
			$secs-since-epoch -= %time-hash{$pair.key} * $pair.value;
			last;
		}
	}
	return %time-hash;
}
sub string-to-secs ( Str $string ) is export {
	my %secs-per-string = :years<15778800>, :year<15778800>, :months<1314900>,
	                      :month<1314900>, :weeks<302400>, :week<302400>, :days<43200>,
	                      :hours<3600>, :mins<60>, :minutes<60>, :minute<60>, :secs<1>,
	                      :seconds<1>, :second<1>,
	                      :ms<0.001>, :milliseconds<0.001>;
	say "string-to-secs got Str: [$string]";
	if $string ~~ / (\d+) ' '? (\S+) / {
		my $in-num = ~$0;
		my $in-unit = ~$1;
		say "in-num: [$in-num] in-unit: [$in-unit]";
		for %secs-per-string.kv -> $unit, $secs {
			say "checking unit: [$unit]";
			if $unit eq $in-unit {
				say "Unit [$unit]";
				return $secs * $in-num;
			}
		}
	}
	else {
		say "Didn't match regex";
		return Nil;
	}
}
sub format-time ( $time-since-epoch ) is export {
	return if $time-since-epoch == 0;
	my Str $tell_return;
	my $tell_time_diff = now.Rat - $time-since-epoch;
	my $sign = $tell_time_diff < 0 ?? "" !! "ago";
	$tell_time_diff .= abs;
	say $tell_time_diff;
	return irc-text('[Just now]', :color<teal>) if $tell_time_diff < 1;
	#return "[Just Now]" if $tell_time_diff < 1;
	my %time-hash = from-secs($tell_time_diff);
	$tell_return = '[';
	for %time-hash.keys -> $key {
		$tell_return ~= sprintf '%.2f', %time-hash{$key};
		$tell_return ~= " $key ";
	}
	$tell_return ~= "$sign]";
	return irc-text($tell_return, :color<teal> );
}
