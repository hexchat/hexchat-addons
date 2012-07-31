# Name:		showall-002.pl
# Version:	002
# Author:	LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:		2010-04-30
# Description:	Create a /showall command that re-shows all hidden windows
#               If all tabs were previously hidden and you show one, the rest
#                 will be displayed as well (can be disabled)

# Version History
# 001  2010-04-30 Initial Version
# 002  2010-04-30 Create option for always showing on bringing to front

use strict;
use warnings;
use Xchat qw(:all);

# Do you want to always show all when bringing to font?
my $show_on_front = 1;

register('Show All', '002', 'Add /showall to show all hidden windows');

my $everything_hidden = 0;

hook_command('showall', sub {
	my @channels = get_list('channels');
	foreach (@channels) {
		if (context_info($_->{context})->{win_status} eq 'hidden') {
			set_context($_->{context});
			command('gui show');
		}
	}
	return EAT_ALL;
}, {help_text => 'Usage: /showall, show all hidden windows'});

hook_print("Focus Window", \&show_from_hidden) if ($show_on_front);

sub show_from_hidden {
	if ($everything_hidden) {
		command('showall');
		$everything_hidden = 0;
	}
	return EAT_NONE;
}

hook_timer(250, sub {
	if (!$everything_hidden && get_info('win_status') eq 'hidden') {
		my @channels = get_list('channels');
		$everything_hidden = 1; # assume to be true
		foreach (@channels) {
			if (context_info($_->{context})->{win_status} ne 'hidden') {
				$everything_hidden = 0;
				last;
			}
		}
	}
	return KEEP;
}) if ($show_on_front);
