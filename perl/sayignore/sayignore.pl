# Name:        sayignore-001.pl
# Version:     001
# Author:      LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:        2009-09-09
# Description: Say what your ignore list is in the channel.
#              You can specify what items to say in the list, based on ignore type

# Version History
# 001  2009-09-09 Initial Version for someone in #xchat

use Xchat qw(:all);
use strict;
use warnings;

register('Say Ignore', '001', 'Send your ignore list to the channel');

hook_command('sayignore', \&cmd_sayignore, { help_text => 'Usage: sayignore [private|notice|channel|ctcp|invite|dcc], send list of ignores to channel' });

sub cmd_sayignore {
	my %ignoretypes = (
		'private' => 1,
		'notice' => 2,
		'channel' => 4,
		'ctcp' => 8,
		'invite' => 16,
		'unignore' => 32,
		'nosave' => 64,
		'dcc' => 128
	);
	if ($_[1][1] && !defined $ignoretypes{lc $_[1][1]}) {
		prnt('Unknown type, valid types: private, notice, channel, ctcp, invite, dcc');
	}
	else {
		my $checkflag = ($_[1][1] ? $ignoretypes{lc $_[1][1]} : 4);
		my @ignoremasks = ();
		foreach (get_list 'ignore') {
			push (@ignoremasks, $_->{mask}) if ($_->{flags} & $checkflag && ! ($_->{flags} & 32));
		}
		
		if (@ignoremasks) {
			command('say My '.($checkflag == 4 ? 'channel' : lc $_[1][1]). ' ignore list: '. join(', ', @ignoremasks));
		}
		else {
			command('say My '.($checkflag == 4 ? 'channel' : lc $_[1][1]). ' ignore list is empty');
		}
	}
	return EAT_XCHAT;
}
