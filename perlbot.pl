#!/usr/bin/env perl
use strict;  use warnings; use diagnostics;
use English; use utf8;     use feature 'unicode_strings';

package PerlBot;
use base qw(Bot::BasicBot);
our $VERSION = 0.2;

use IPC::System::Simple qw(system capture);
use Encode  'decode_utf8';

# Debian package list:
# 	perl curl
# Debian perl package list:
# 	liburi-find-perl libpoe-component-sslify-perl libbot-basicbot-perl
# 	libipc-system-simple-perl

# Arch package list:
# 	perl curl
# Arch AUR package list:
# 	perl-bot-basicbot
# Arch perl package list:
# 	perl-uri-find

# CPAN package: IPC::System::Options

#START
#END
my $nickname         = $username;
my $alt_nickname_1   = $username . "-";
my $alt_nickname_2   = $username . "_";

my $history_file     = $username . '_history.txt';


sub said {
	my($self, $message) = @_;

	print "sub said called\n";

	my $body     = $message->{body};
	my $who_said = $message->{who};
	my @to_say   = ();
	push my (@said_args), $who_said, $body, $username;
	open my $history_fh, '>>', "$history_file" or print "Could not open history file, Error $?\n";
	print $history_fh "<$who_said> $body\n" or print "Failed to append to $history_file, Error $?\n";
	close $history_fh or print "Could not close $history_file, Error $?\n";

	my @results = capture($^X, "said.pl", @said_args);

	print 'Results: ' . @results . "\n";

	foreach my $line (@results) {
		if ($line =~ /^%/) {
			$line =~ s/^%//;
			chomp $line;
			push @to_say, decode_utf8($line);
		}
	}
	foreach my $line_to_say (@to_say) {
		$self->say(
			{   channel => ( $self->channels ),
				body    => "$line_to_say\n",
			}
		);
	}
}

### actual bot ###
PerlBot->new(
	server    =>   "$server_address",
	port      =>   "$server_port",
	channels  => [ "$server_channels" ],

	nick      =>   "$nickname",
	alt_nicks => [ "$alt_nickname_1", "$alt_nickname_2" ],
	username  =>   "$username",
	name      =>   "$real_name",
	ssl       =>    1
)->run();     # Start the bot
