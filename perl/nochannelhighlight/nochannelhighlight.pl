# Name:        nochannelhighlight-001.pl
# Version:     001
# Author:      LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:        2010-04-27
# Description: Do not highlight messages that are found in preset channels

# Version History
# 001  2010-04-27 Initial Version

use strict;
use warnings;
use Xchat qw(register hook_server get_prefs command hook_timer KEEP REMOVE EAT_NONE);

# -------- CONFIGURATION --------
# List the channels here you do not wish to highlight, keep things lower
# case, and use the same form as what is listed
my %no_highlight = (
	'#testing' => 0,
	'#annoyingchan' => 0,
);

register('No Channel Highlight', '001', 'Don\'t highlight if message is in specific channel');

hook_server('PRIVMSG', \&no_chan_highlight);

sub no_chan_highlight {
	if (defined $no_highlight{lc $_[0][2]}) {
		my ($from) = $_[0][0] =~ m/^:([^!]+)/;
		my $current_list = get_prefs('irc_no_hilight');
		# perhaps the list is blank
		unless ($current_list) {
			command("set -quiet irc_no_hilight $from");
			# unset after event has gone through
			delaycommand("set -e -quiet irc_no_hilight");
		}
		# make sure the user isn't already in the list
		elsif ($current_list !~ m/(?:^|,)$from(?:$|,)/i) {
			command("set -quiet irc_no_hilight $current_list,$from");
			# after the event has gone through, set to original
			delaycommand("set -quiet irc_no_hilight $current_list");
		}
	}
	return EAT_NONE;
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
