#!/usr/bin/perl
use warnings;
use Safe;
use utf8;
use feature 'unicode_strings';

use Benchmark qw(:hireswallclock);
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

my $command = $ARGV[0];
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

if ($timedOut) {
	print "Timeout!\n";
	my $td = timediff( $t1, $t0 );
	print timestr($td), "\n";
	if ( defined $printBuffer ) { print $printBuffer }
}
else {
	if ( defined $userError ) {
		if ($userError ne '0') {
			print STDERR $userError
			}
	}
	if ( defined $printBuffer ) { print $printBuffer }

}
