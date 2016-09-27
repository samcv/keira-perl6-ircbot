#!/usr/bin/env perl
use strict;
use warnings;
use diagnostics;
use English;
use utf8;
use feature 'unicode_strings';

package PerlBot;
use base qw(Bot::BasicBot);
our $VERSION = 0.3.2;
use Encode 'decode_utf8';

# Debian package list:
# 	perl curl moreutils
# Debian perl package list:
# 	liburi-find-perl libpoe-component-sslify-perl libbot-basicbot-perl
# 	libipc-system-simple-perl

# Arch package list:
# 	perl curl moreutils
# Arch AUR package list:
# 	perl-bot-basicbot
# Arch perl package list:
# 	perl-uri-find
binmode( STDOUT, ":utf8" ) or die "Failed to set binmode on STDOUT, Error $?\n";

#binmode( STDOUT, ":encoding(UTF-8)" ) or die "Failed to set binmode on STDOUT, Error $?\n";
my ( $username, $real_name, $server_address, $server_port, $server_channels ) = @ARGV;

for ( $username, $real_name, $server_address, $server_port, $server_channels ) {
	if ( !defined ) {
		print
			"Usage: perlbot.pl \"username\" \"real name\" \"server address\" \"server port\" \"server channel\"\n";
		exit 1;
	}
}

my $nickname       = $username;
my $alt_nickname_1 = $username . "-";
my $alt_nickname_2 = $username . "_";

my $history_file = $username . '_history.txt';

sub said {
	my ( $self, $message ) = @_;
	print "sub said called\n";
	my $body     = $message->{body};
	my $who_said = $message->{who};
	my $channel  = $message->{channel};
	my @to_say   = ();

	utf8::encode($who_said);
	utf8::encode($body);
	utf8::encode($channel);
	utf8::encode($username);

	push my (@said_args), 'said.pl', $who_said, $body, $username;
	open my $SAID_OUT, '-|', "perl", @said_args
		or print 'Cannot open $SAID_OUT ' . "pipe, Error $?\n";

	binmode( $SAID_OUT, ":encoding(UTF-8)" )
		or die 'Failed to set binmode on $SAID_OUT, Error ' . "$?\n";

	while ( defined( my $line = <$SAID_OUT> ) ) {

		#print decode_utf8($line);
		print $line;
		if ( $line =~ s/^%// ) {
			$self->say(
				{   channel => ( $self->channels ),

					#body    => decode_utf8($line),
					body => $line,
				}
			);
		}

	}
	close $SAID_OUT;
	open my $history_fh, '>>', "$history_file" or print "Could not open history file, Error $?\n";
	binmode( $history_fh, ":utf8" )
		or die "Failed to set binmode on $history_fh, Error $?\n";
	print $history_fh "<$who_said> $body\n"
		or print "Failed to append to $history_file, Error $?\n";
	close $history_fh or print "Could not close $history_file, Error $?\n";

	return;

}
### actual bot ###
PerlBot->new(
	server   => "$server_address",
	port     => "$server_port",
	channels => ["$server_channels"],

	nick      => "$nickname",
	alt_nicks => [ "$alt_nickname_1", "$alt_nickname_2" ],
	username  => "$username",
	name      => "$real_name",
	ssl       => 1
)->run();    # Start the bot
