#!/usr/bin/env perl
# Perl script for processing channel join and part messages
use strict;
use warnings;
use utf8;
use English;
our $VERSION = 0.4;
use feature 'unicode_strings';
binmode STDOUT, ':encoding(UTF-8)' or print "Failed to set binmode on STDOUT, Error $ERRNO\n";

my ( $nick, $channel, $event, $bot_username ) = @ARGV;
print "nick: \"$nick\" channel: \"$channel\" event: \"$event\" bot username: \"$bot_username\"\n";
if ( !defined $nick || !defined $channel || !defined $event || !defined $bot_username ) {
	print "Usage: channel_event.pl nick channel event bot_username\n";
	exit 1;
}
elsif ( $event ne 'chanjoin' and $event ne 'chanpart' and $event ne 'chansaid' ) {
	print "Unknown event!  I only know about chanjoin, chanpart and chansaid\n";
	exit;
}
print "Nick $nick $event channel $channel\n";

my $is_in_file         = 0;
my $channel_event_file = $bot_username . '_event.txt';
my $event_date         = time;
print "My event date is $event_date\n";
my @event_after_array;
my $event_file_exists = 0;
if ( -f $channel_event_file ) {
	$event_file_exists = 1;
}

# If the event file already exists
if ( $event_file_exists == 1 ) {

	# print "Event file found\n";
	open my $event_read_fh, '<', "$channel_event_file"
		or print "Could not open seen file, Error $ERRNO\n";
	binmode $event_read_fh, ':encoding(UTF-8)'
		or print 'Failed to set binmode on $event_read_fh, Error' . "$ERRNO\n";
	my @event_array = <$event_read_fh>;
	my ( $event_who_update, $event_spoke_update, $event_join_update, $event_part_update );
	foreach my $line2 (@event_array) {
		chomp $line2;
		$line2 =~ m/^<(\S+?)> (\d+) (\d+) (\d+)/;
		my $event_who_file   = $1;
		my $event_spoke_file = $2;
		my $event_join_file  = $3;
		my $event_part_file  = $4;

		# If the person on this line doesn't match, then we need to push it to the array
		# So we don't forget about them.
		if ( $nick !~ /^$event_who_file?.?/i ) {
			push @event_after_array, "$line2";
		}

		# If it matches then we need to update its contents
		else {
			print "Matching, attempting to modify contents\n";
			$is_in_file       = 1;
			$event_who_update = $nick;

			if ( $event eq 'chanjoin' ) { $event_join_update  = $event_date }
			if ( $event eq 'chanpart' ) { $event_part_update  = $event_date }
			if ( $event eq 'chansaid' ) { $event_spoke_update = $event_date }

			if ( !defined $event_join_update )  { $event_join_update  = $event_join_file }
			if ( !defined $event_part_update )  { $event_part_update  = $event_part_file }
			if ( !defined $event_spoke_update ) { $event_spoke_update = $event_spoke_file }
			print
				"UPDATE: who: $event_who_update spoke: $event_spoke_update join: $event_join_update part: $event_part_update\n";

			push @event_after_array,
				"<$event_who_update> $event_spoke_update $event_join_update $event_part_update";
		}

	}
}

# If the event file hasn't been created yet we need to create it
else {
	print "Event file $channel_event_file does not exist yet, creating\n";
	my ( $event_who_new, $event_spoke_new, $event_join_new, $event_part_new );
	$event_who_new = $nick;
	if    ( $event eq 'chanjoin' ) { $event_join_new  = $event_date }
	elsif ( $event eq 'chanpart' ) { $event_part_new  = $event_date }
	elsif ( $event eq 'chansaid' ) { $event_spoke_new = $event_date }

	if ( !defined $event_join_new )  { $event_join_new  = 0 }
	if ( !defined $event_part_new )  { $event_part_new  = 0 }
	if ( !defined $event_spoke_new ) { $event_spoke_new = 0 }

	push @event_after_array, "<$nick> $event_spoke_new $event_join_new $event_part_new";
}
my ( $event_join_add, $event_part_add, $event_spoke_add );

# If the person is not in the file yet we need to add them
if ( $is_in_file == 0 and $event_file_exists == 1 ) {
	print "Haven't seen \"$nick\" before, adding\n";
	if    ( $event eq 'chanjoin' ) { $event_join_add  = $event_date }
	elsif ( $event eq 'chanpart' ) { $event_part_add  = $event_date }
	elsif ( $event eq 'chansaid' ) { $event_spoke_add = $event_date }

	if ( !defined $event_join_add )  { $event_join_add  = 0 }
	if ( !defined $event_part_add )  { $event_part_add  = 0 }
	if ( !defined $event_spoke_add ) { $event_spoke_add = 0 }
	push @event_after_array, "<$nick> $event_spoke_add $event_join_add $event_part_add";

}
open my $event_write_fh, '>', "$channel_event_file"
	or print "Could not open seen file, Error $ERRNO\n";
binmode $event_write_fh, ':encoding(UTF-8)'
	or print 'Failed to set binmode on $event_read_fh, Error' . "$ERRNO\n";
print {$event_write_fh} join( "\n", @event_after_array );
close $event_write_fh;
