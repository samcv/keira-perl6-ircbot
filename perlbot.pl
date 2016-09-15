#!/usr/bin/env perl
use strict;
use warnings;
use diagnostics;

package PerlBot;
our $VERSION = 0.1;
use base qw(Bot::BasicBot);
use URI::Find;
use LWP::Simple;
use WWW::Mechanize;
use IPC::System::Simple qw(system capture);
use Encode 'decode_utf8';
#use IPC::System::Options 'system', 'readpipe', 'run', 'capture', -lang=>"en_US.UTF-8";

use feature 'unicode_strings';
use utf8;
# Debian package list:
# perl curl
# Debian perl package list:
# liburi-find-perl libpoe-component-sslify-perl libbot-basicbot-perl libwww-mechanize-perl
# libipc-system-simple-perl

# Arch package list:
# perl curl
# Arch perl package list:
# perl-uri-find

#CPAN package: IPC::System::Options

my $ticked = 0;

#START
#END
my $nickname       = $username;
my $alt_nickname_1 = $username . "-";
my $alt_nickname_2 = $username . "_";
my $last_line;
my $last_line_who;

sub said {
	print "sub said Called\n";
	#&forkit();
	my $self    = shift;
	my $message = shift;
	my $body    = $message->{body};
	my $who_said = $message->{who};
	my $line_to_say = "%";

	my @said_args;
	push @said_args, $who_said;
	push @said_args, $body;
	# Run said.pl
	my @results = capture($^X, "said.pl", @said_args);

	print "Results: ";
	print @results;
	print "\n";
	foreach my $line (@results) {
		if ($line =~ /^%/) {
			$line =~ s/^%//;
			$line_to_say = $line;  chomp $line_to_say;
			$line_to_say = decode_utf8($line_to_say);
		}
	}
	if ($line_to_say ne "%") {
		$self->say(
			{   channel => ( $self->channels ),    #[0],
				body    => "$line_to_say\n",
			}
		);
	}
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
)->run(); # Start the bot
