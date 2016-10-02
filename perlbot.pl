#!/usr/bin/env perl
use strict;
use warnings;
use diagnostics;
use English;
use utf8;
use feature 'unicode_strings';

package PerlBot;
use base qw(Bot::BasicBot);
our $VERSION = 0.4;
use Encode 'decode_utf8';

# CPAN package list:
#	 URL::Search
# Debian package list:
# 	perl curl moreutils
# Debian perl package list:
# 	libpoe-component-sslify-perl libbot-basicbot-perl

# Arch package list:
# 	perl curl moreutils
# Arch AUR package list:
# 	perl-bot-basicbot

binmode( STDOUT, ':encoding(UTF-8)' ) or die "Failed to set binmode on STDOUT, Error $?\n";

my ( $bot_username, $real_name, $server_address, $server_port, $server_channels ) = @ARGV;

for ( $bot_username, $real_name, $server_address, $server_port, $server_channels ) {
	if ( !defined ) {
		print
			'Usage: perlbot.pl "username" "real name" "server address" "server port" "server channel"'
			. "\n";
		exit 1;
	}
}

my $nickname       = $bot_username;
my $alt_nickname_1 = $bot_username . q(-);
my $alt_nickname_2 = $bot_username . q(_);

my $history_file = $bot_username . '_history.txt';

sub said {
	my ( $self, $message ) = @_;
	my $body     = $message->{body};
	my $who_said = $message->{who};
	my $channel  = $message->{channel};
	my @to_say   = ();

	utf8::encode($who_said);
	utf8::encode($body);
	utf8::encode($channel);
	utf8::encode($bot_username);

	push my (@said_args), 'said.pl', $who_said, $body, $bot_username;
	open my $SAID_OUT, '-|', "perl", @said_args
		or print 'Cannot open $SAID_OUT ' . "pipe, Error $?\n";

	binmode( $SAID_OUT, ":encoding(UTF-8)" )
		or print 'Failed to set binmode on $SAID_OUT, Error ' . "$?\n";

	while ( defined( my $line = <$SAID_OUT> ) ) {
		print $line;
		if ( $line =~ s/^%// ) {
			$self->say(
				{   channel => ( $self->channels ),
					body    => $line,
				}
			);
		}

	}
	close $SAID_OUT;
	return;

}

sub chanjoin {
	my ( $self, $message ) = @_;
	my $chanjoin_channel = $message->{channel};
	my $chanjoin_nick    = $message->{who};
	my $event            = 'chanjoin';

	push my (@chanjoin_args), 'channel_event.pl', $chanjoin_nick, $chanjoin_channel, $event,
		$bot_username;
	open my $CHANJOIN_OUT, '-|', 'perl', @chanjoin_args
		or print 'Cannot open $CHANJOIN_OUT ' . "pipe, Error $?\n";

	binmode( $CHANJOIN_OUT, ":encoding(UTF-8)" )
		or print 'Failed to set binmode on $CHANJOIN_OUT, Error ' . "$?\n";

	while ( defined( my $line = <$CHANJOIN_OUT> ) ) {
		print $line;
		if ( $line =~ s/^%// ) {
			$self->say(
				{   channel => ( $self->channels ),
					body    => $line,
				}
			);
		}

	}
	close $CHANJOIN_OUT;
	return;
}

sub chanpart {
	my ( $self, $message ) = @_;
	my $chanpart_channel = $message->{channel};
	my $chanpart_nick    = $message->{who};
	my $event            = 'chanpart';

	push my (@chanjoin_args), 'channel_event.pl', $chanpart_nick, $chanpart_channel, $event,
		$bot_username;
	open my $CHANPART_OUT, '-|', 'perl', @chanjoin_args
		or print 'Cannot open $CHANPART_OUT ' . "pipe, Error $?\n";

	binmode( $CHANPART_OUT, ":encoding(UTF-8)" )
		or print 'Failed to set binmode on $CHANPART_OUT, Error ' . "$?\n";

	while ( defined( my $line = <$CHANPART_OUT> ) ) {
		print $line;
		if ( $line =~ s/^%// ) {
			$self->say(
				{   channel => ( $self->channels ),
					body    => $line,
				}
			);
		}

	}
	close $CHANPART_OUT;
	return;
}

### actual bot ###
PerlBot->new(
	server   => "$server_address",
	port     => "$server_port",
	channels => ["$server_channels"],

	nick      => "$nickname",
	alt_nicks => [ "$alt_nickname_1", "$alt_nickname_2" ],
	username  => "$bot_username",
	name      => "$real_name",
	ssl       => 1,
	flood     => 1
)->run();    # Start the bot
