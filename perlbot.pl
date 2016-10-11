#!/usr/bin/env perl
use strict;
use warnings;
use diagnostics;
use English;
use utf8;
use feature 'unicode_strings';

package PerlBot;
use base qw(Bot::BasicBot);
our $VERSION = 0.5;
use Encode 'decode_utf8';

# CPAN package list:
#	 URL::Search
# Debian package list:
# 	perl curl moreutils
# Debian perl package list:
# 	libpoe-component-sslify-perl libbot-basicbot-perl libencode-detect-perl
#	libtext-unidecode-perl

# Arch package list:
# 	perl curl moreutils
# Arch AUR package list:
# 	perl-bot-basicbot perl-encode-detect perl-text-unidecode

binmode STDOUT, ':encoding(UTF-8)' or print {*STDERR} "Failed to set binmode on STDOUT, Error $?\n";
binmode STDERR, ':encoding(UTF-8)' or print {*STDERR} "Failed to set binmode on STDERR, Error $?\n";

my ( $bot_username, $real_name, $server_address, $server_port, $server_channels ) = @ARGV;

for ( $bot_username, $real_name, $server_address, $server_port, $server_channels ) {
	if ( !defined ) {
		print 'Usage: perlbot.pl "username" "real name" "server address" "server port" "server channel"' . "\n";
		exit 1;
	}
}
my $said_script;
if ( -f 'said.in.pl' ) {
	$said_script = 'said.in.pl';
	print {*STDERR} "Found $said_script\n";
}
elsif ( -f 'said.pl' ) {
	$said_script = 'said.pl';
	print {*STDERR} "Found said.pl\n";
}
else {
	print {*STDERR} "Could not find said.pl or said.in.pl\n";
	exit 1;
}

my $nickname       = $bot_username;
my $alt_nickname_1 = $bot_username . q(-);
my $alt_nickname_2 = $bot_username . q(_);

my $history_file = $bot_username . '_history.txt';

sub process_children {
	my ( $self, $fh ) = @_;
	while ( defined( my $line = <$fh> ) ) {
		print {*STDERR} $line;
		if ( $line =~ s/^%// ) {
			$self->say(
				{   channel => ( $self->channels ),
					body    => $line,
				}
			);
		}
		elsif ( $line =~ s/^\$(.*?)%(.*)/$2/ ) {
			my $msg_who = $1;
			$self->say(
				{   channel => 'msg',
					body    => $line,
					who     => $msg_who,
				}
			);
		}

	}
}

sub said {
	my ( $self, $message ) = @_;
	my $body      = $message->{body};
	my $who_said  = $message->{who};
	my $channel   = $message->{channel};
	my $addressed = $message->{address};

	my @to_say = ();
	my $event  = 'chansaid';

	utf8::encode($who_said);
	utf8::encode($body);
	utf8::encode($channel);
	utf8::encode($bot_username);
	if ( defined $addressed ) {
		utf8::encode($addressed);

		# If we are being addressed BasicBot will strip the bots name from the message
		# Here we add it back add the bots username back onto into the body
		if ( $addressed eq $bot_username ) {
			$body = $addressed . ": $body";
		}
	}

	push my (@chansaid_args), 'channel_event.pl', $who_said, $channel, $event, $bot_username;
	open my $CHANSAID_OUT, '-|', 'perl', @chansaid_args
		or print {*STDERR} 'Cannot open $CHANSAID_OUT ' . "pipe, Error $?\n";

	binmode( $CHANSAID_OUT, ":encoding(UTF-8)" )
		or print {*STDERR} 'Failed to set binmode on $CHANSAID_OUT, Error ' . "$?\n";

	process_children( $self, $CHANSAID_OUT );

	close $CHANSAID_OUT;

	push my (@said_args), "$said_script", $who_said, $body, $bot_username, $channel;
	open my $SAID_OUT, '-|', 'perl', @said_args
		or print 'Cannot open $SAID_OUT ' . "pipe, Error $?\n";

	binmode $SAID_OUT, ':encoding(UTF-8)'
		or print 'Failed to set binmode on $SAID_OUT, Error ' . "$?\n";

	process_children( $self, $SAID_OUT );

	close $SAID_OUT;

	return;

}

sub userquit {
	my ( $self, $message ) = @_;
	my $chanpart_channel = $message->{channel};
	my $chanpart_nick    = $message->{who};
	my $event            = 'chanpart';

	push my (@userquit_args), 'channel_event.pl', $chanpart_nick, $server_channels, $event, $bot_username;
	open my $USERQUIT_OUT, '-|', 'perl', @userquit_args
		or print 'Cannot open $USERQUIT_OUT ' . "pipe, Error $?\n";

	binmode $USERQUIT_OUT, ':encoding(UTF-8)'
		or print "Failed to set binmode on USERQUIT_OUT, Error $?\n";

	process_children( $self, $USERQUIT_OUT );

	close $USERQUIT_OUT;
	return;
}

sub chanjoin {
	my ( $self, $message ) = @_;
	my $chanjoin_channel = $message->{channel};
	my $chanjoin_nick    = $message->{who};
	my $event            = 'chanjoin';

	push my (@chanjoin_args), 'channel_event.pl', $chanjoin_nick, $chanjoin_channel, $event, $bot_username;
	open my $CHANJOIN_OUT, '-|', 'perl', @chanjoin_args
		or print {*STDERR} 'Cannot open $CHANJOIN_OUT ' . "pipe, Error $?\n";

	binmode $CHANJOIN_OUT, ':encoding(UTF-8)'
		or print {*STDERR} 'Failed to set binmode on $CHANJOIN_OUT, Error ' . "$?\n";

	process_children( $self, $CHANJOIN_OUT );

	close $CHANJOIN_OUT or print {*STDERR} 'Cannot close $CHANJOIN_OUT ' . "pipe, Error $?\n";
	return;
}

sub chanpart {
	my ( $self, $message ) = @_;
	my $chanpart_channel = $message->{channel};
	my $chanpart_nick    = $message->{who};
	my $event            = 'chanpart';

	push my (@chanjoin_args), 'channel_event.pl', $chanpart_nick, $chanpart_channel, $event, $bot_username;
	open my $CHANPART_OUT, '-|', 'perl', @chanjoin_args
		or print {*STDERR} 'Cannot open $CHANPART_OUT ' . "pipe, Error $?\n";

	binmode $CHANPART_OUT, ':encoding(UTF-8)'
		or print {*STDERR} 'Failed to set binmode on $CHANPART_OUT, Error ' . "$?\n";

	process_children( $self, $CHANPART_OUT );

	close $CHANPART_OUT or print {*STDERR} 'Cannot close $CHANPART_OUT ' . "pipe, Error $?\n";
	return;
}

### actual bot ###
PerlBot->new(
	server     => "$server_address",
	port       => "$server_port",
	channels   => ["$server_channels"],
	msg_length => 1000,
	nick       => "$nickname",
	alt_nicks  => [ "$alt_nickname_1", "$alt_nickname_2" ],
	username   => "$bot_username",
	name       => "$real_name",
	ssl        => 1,
	flood      => 1
)->run();    # Start the bot
