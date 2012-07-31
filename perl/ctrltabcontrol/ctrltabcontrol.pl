# Name:		ctrltabcontrol-004.pl
# Version:	004
# Author:	LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:		2010-07-07
# Description:	Allow for ctrl-tab between channels in the order you last viewed them
#               as well as ctrl-shift to the channel with the most recent activity.

# Version History
# 001  2009-05-13 Initial Code
# 002  2009-05-13 Remove duplicate code, think all cases matched
# 003  2009-08-02 ctrl-space for tabbing to recent activity, highlights given priority
# 004  2010-07-07 Hopefully fix ctrl-space on some systems
#			add PMs to priority, after highlight

use strict;
use warnings;
use Xchat qw (:all);

register('Ctrl Tab Control', '004', 'Allow for ctrl-tab between channels in the order you last viewed them');

hook_print('Key Press', \&check_keys);
hook_print('Focus Tab', \&update_order);

my @context_order = ();
my $mid_context = 0; # init to 0 for this script

my @highlight_order = ();
my @message_order = ();

hook_print($_, \&update_activity, { data => $_ })
	foreach('Channel Action Hilight', 'Channel Msg Hilight', 'Channel Action', 'Channel Message',
			'Private Message to Dialog', 'Private Action to Dialog');

sub check_keys {
	# if we receive a ctrl, reset the cycle order from current, to allow ctrl to be held down with tab multiple times
	if ($_[0][0] == 65507 || $_[0][0] == 65508) {
		return reset_order();
	}
	# shift tab case
	elsif ($_[0][0] == 65056 && $_[0][1] & 5) {
		return next_in_list(1);
	}
	# cycle a bit
	elsif ($_[0][0] == 65289 && $_[0][1] & 4) {
		return next_in_list(-1);
	}
	# ctrl space case
	elsif ($_[0][0] == 32 && $_[0][1] & 4 ) {
		return next_activity();
	}
	else {
		return EAT_NONE;
	}
}

# attempt to generalize both ctrl-tab and ctrl-shift-tab
sub next_in_list {
	# accept -1 and 1, yes my code, but I like to be robust
	my $modifier = ($_[0] ? int $_[0] : -1);

	my $context = get_context();
	my $i;
	# going up in order, with newest at end
	if ($modifier > 0) {
		$i = 0;
		while ($i < scalar @context_order) {
			last if $context_order[$i++] == $context;
		}
	}
	# start from the end of the list and go down
	else {
		$i = scalar @context_order;
		while ($i-- > 0) {
			last if $context_order[$i] == $context;
		}
	}

	# run in circles as long as there are circles to run (or the order)
	while (scalar @context_order) {
		# if incrementing, deal with if it wraps to 0
		if ($modifier > 0) { $i = $i % scalar @context_order }
		# if decrementing, at 0 needs to be at the end instead
		else               { $i = ($i - 1 + @context_order) % @context_order }

		# set the focus to the next context in the list, set focus, and $mid_context
		$mid_context = $context_order[$i];
		last if set_context($mid_context);
		# if still in the loop, obviously couldn't set_context, so remove it
		splice @context_order, $i, 1;
	}

	command('gui focus');

	# don't let xchat handle the tab at this point
	return EAT_XCHAT;
}

sub update_order {
	my $context = get_context;
	my $i;
	# only re-order if this wasn't from a temporary swap
	reset_order() if ($context != $mid_context);
	
	# remove from activity list
	for ($i = 0; $i < scalar @highlight_order; $i++) {
		splice @highlight_order, $i, 1 if $highlight_order[$i] == $context;
	}
	for ($i = 0; $i < scalar @message_order; $i++) {
		splice @message_order, $i, 1 if $message_order[$i] == $context;
	}
	
	return EAT_NONE;
}

sub reset_order {
	my $context = get_context();
	# remove from the list of previous ones if it is already there, even if it was done before
	# because it may not have happened before if $mid_context was matched
	for (my $i = 0; $i < scalar @context_order; $i++) {
		splice @context_order, $i, 1 if $context_order[$i] == $context;
	}
	# place the current context at the end
	push @context_order, $context;

	# pressing ctrl may happen for other reasons, as long as it is a reset,
	# do a full reset, including $mid_context
	$mid_context = 0;

	return EAT_NONE;
}

sub next_activity {
	if (scalar @highlight_order) {
		set_context(pop @highlight_order);
	}
	elsif (scalar @message_order) {
		set_context(pop @message_order);
	}
	
	command('gui focus');
	
	return EAT_XCHAT;
}

sub update_activity {
	my $i;
	my $context = get_context();

	# don't do anything if context is the front tab
	return EAT_NONE if $context == find_context();

	# remove from normal if it exists
	for ($i = 0; $i < scalar @message_order; $i++) {
		splice @message_order, $i, 1 if $message_order[$i] == $context;
	}

	if ($_[1] =~ /(?:^Private|Hilight$)/) {
		# remove from highlight if it exists
		for ($i = 0; $i < scalar @highlight_order; $i++) {
			splice @highlight_order, $i, 1 if $highlight_order[$i] == $context;
		}
		push @highlight_order, $context;
	}
	else {
		# don't want to add to normal if in highlight
		push (@message_order, $context) unless (grep $_ eq $context, @highlight_order);
	}
	
	return EAT_NONE;
}
