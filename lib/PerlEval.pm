#!/usr/bin/perl
use warnings;
use Safe;
use utf8;
use feature 'unicode_strings';

use Benchmark qw(:hireswallclock);
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

sub perl_eval {
	my ($command) = @_;
	my ( $t0, $t1 );    # Benchmark
	my $timedOut  = 0;
	my $userError = 0;
	my $printBuffer;
	open( my $buffer, '>', \$printBuffer );
	my $stdout = select($buffer);
	my $cpmt   = new Safe;
	$cpmt->permit_only(qw(:default :base_io sleep rand time localtime));
	eval {
		local $SIG{'ALRM'} = sub { $timedOut = 1; die "alarm\n" };
		$t0 = Benchmark->new;
		alarm 2;
		$cpmt->reval($command);

		alarm 0;
		$t1 = Benchmark->new;
		if ($@) {
			$userError = join '', $@;
		}
	};
	select($stdout);
	my $time_str;
	if ($timedOut) {
		print {*STDERR} "Timeout!\n";
		my $td = timediff( $t1, $t0 );
		$time_str = timestr($td);
	}
	
	return $printBuffer, $userError, $time_str;
}
