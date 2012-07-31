# Name:        greetonchan.pl
# Version:     002
# Author:      LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:        2010-04-29
# Description: Say a message when someone joins one of a list of channels
#              Message will be randomly chosen from a list and won't be sent to users who are regulars

# Version History
# 001  2009-06-24 Initial Version
# 002  2010-04-29 Moved channel name to separate variable, allow more than one channel

use strict;
use warnings;
no warnings 'qw';
use Xchat qw(:all);

register('Greet to Chan', '002', 'Say a message when someone joins a one of a list of channels');

# set list of channels to say here, lower case
my @channels = qw(#yourchannel #channel2);

# set your list of nicks not to message here, lower case
my @regulars = qw(nick1 nick2 nick3);

# have some greetings, use %n for their nick, %c for channel name
my @greetings = (
	'Hello %n',
	'Welcome to %c, %n',
	'%n has arrived!'
);

hook_print('Join', \&greet_join);

sub greet_join {
	# There is a list of users that don't need to be told
	if ((grep $_ eq lc $_[0][1], @channels) && !(grep $_ eq lc $_[0][0], @regulars)) {
		# so if it isn't a regular, say something to them
		my $saying = $greetings[rand $#greetings];
		$saying =~ s/%n/$_[0][0]/g;
		$saying =~ s/%c/$_[0][1]/g;
		delaycommand('say '.$saying);
	}

	return EAT_NONE;
}

# this just makes it so it looks right on your side
sub delaycommand {
	my $command = $_[0];
	hook_timer( 0,
		sub {
			command($command);
			return REMOVE;
		}
	); 
	return EAT_NONE;
}
