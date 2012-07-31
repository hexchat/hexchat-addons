# Name:        masshighlightignore-004.pl
# Version:     004
# Author:      LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:        2010-02-02
# Description: Convert highlight events to normal events if more than a set number (4) nicks
#              are present in the highlight line. This script will also eat common /names
#              spam, and so does not require the other script

# Version History
# 001  2010-02-01 Initial Version
# 002  2010-02-01 does an actual ignore on a specific spamming form, which spams the /names
# 003  2010-02-01 support for cap identify-msg (regardless of if set or not), better delay
# 004  2010-02-02 Now will not change the tab color, even with the bug in XChat

use strict;
use warnings;
use Xchat qw(:all);

# Change how many nicks can show up as individual words and still be a highlight
# default value left at 4, due to presense of generic nicks on channels, like "stats" and "bot"
use constant ALLOWED_MAX => 4;

register('Mass Highlight Ignore', '003', 'Keep mass highlights from highlighting you');

hook_server('PRIVMSG', \&names_and_mass);

# check both for /names spam and mass highlighting, as some parts are duplicated
sub names_and_mass {
	# save the old context for later, context safe (not absolutely needed, but meh)
	my $orig_context = get_context;
	
	# there are several check to do, but only if in a channel, the easy way to check that is to set context
	# to $_[0][2] which is the target. If you are the target, probably don't have a window open with self
	if (set_context($_[0][2])) {
		# later on, checking against highlights, so need self
		my $mynick = get_info('nick');
		# normally mass highlights don't go color code happy... but they could!
		my $line = strip_code($_[1][3]);
		my ($from) = $_[0][0] =~ m/^:([^!]+)/;

		my $inword = $_[0][3];
		# remove the initial bit and save for later, keeping with idmsg or not
		$inword =~ s/^(:[+\-]?)//;
		my $start = ($1 ? $1 : ':');

		# in a /names spam, the first nick will be that of the spammers (and match the from, including colon)
		# then just check if the second word is on the channel, if so, assume
		if ($from eq $inword && $_[0][4]) {
			my $check = $_[0][4];
			my $modes = context_info->{nickprefixes};
			$check =~ s/^[\Q$modes\E]*//;
			if (user_info($check)) {
				my $mask = $_[0][0];
				$mask =~ s/^:[^@]+/*!*/;
				delaycommand("ignore $mask CHAN QUIET");
				command("recv $_[0][0] $_[0][1] $_[0][2] $start<this /names spammer has been ignored: $mask>");
				return EAT_ALL;
			}
		}
		# if it isn't /names spam, check to see if this would be a nick highlight, also check to see
		# if it is a mass nick highlight, don't worry about extra words
		# this isn't done with case insensitivity, due to if they type it out, perhaps pay attention
		elsif ($line =~ m/\b\Q$mynick\E\b/ && is_mass_highlight($line)) {
			# temporarily add the user to the irc_no_hilight list
			add_no_highlight($from);
		}
		# be nice, and set the context back to what it was
		set_context($orig_context);
	}
	return EAT_NONE;
}

# due to the way XChat changes the tab color for highlight messages, the best way
# around it is adding a nick to the nicknames not to highlight field
sub add_no_highlight {
	my $current_list = get_prefs('irc_no_hilight');
	# perhaps the list is blank
	unless ($current_list) {
		# set to $_[0]
		command("set -quiet irc_no_hilight $_[0]");
		# unset after event has gone through
		delaycommand("set -e -quiet irc_no_hilight");
	}
	# make sure the user isn't already in the list
	elsif ($current_list !~ m/(?:^|,)$_[0](?:$|,)/i) {
		# tack on $_[0]
		command("set -quiet irc_no_hilight $current_list,$_[0]");
		# after the event has gone through, set to original
		delaycommand("set -quiet irc_no_hilight $current_list");
	}
}

# loop through the user list for the context and match against the line
# this would be ugly, but only will be called if the line would otherwise be highlighted
# returns 1 or 0
sub is_mass_highlight {
	my $count = 0;
	my @users = get_list 'users';
	foreach (@users) {
		# mass nick spammers don't bother changing the case of nicks, so forget about case insensitivity
		$count++ if $_[0] =~ m/\b\Q$_->{nick}\E\b/;
		last if $count > ALLOWED_MAX;
	}
	return ($count > ALLOWED_MAX);
}

# my favorite delaycommand sub, so stuff happens after the raw is totally processed
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
