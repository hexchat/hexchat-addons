# Name:        massnamesspamignore-002.pl
# Version:     002
# Author:      LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:        2010-02-01
# Description: Ignore users who join a channel and spam the contents of /names to the channel.
#              The method detected is fairly limited for efficency, so may not catch all cases,
#              but is adequate for a current set of attacks.
# Note:        This is a subset of Mass Highlight Ignore

# Version History
# 001  2010-02-01 Initial Version
# 002  2010-02-01 support for cap identify-msg (regardless of if set or not), better delay

use strict;
use warnings;
use Xchat qw(:all);

register('Mass /names Spam Ignore', '002', 'Ignore users who spam /names to a room');

hook_server('PRIVMSG', \&names_spam_minimize);

sub names_spam_minimize {
	# in a /names spam, the first nick will be that of the spammers (and match the from, including colon)
	# then just check if the second word is on the channel, if so, assume
	# first, must deal with CAP identify-msg
	my $inword = $_[0][3];
	$inword =~ s/^(:[+\-]?)/:/;
	my $start = ($1 ? $1 : ':');
	if ($_[0][0] =~ m/^\Q$inword/ && $_[0][4]) {
		my $check = $_[0][4];
		my $modes = context_info->{nickprefixes};
		$check =~ s/^[\Q$modes\E]*//;
		set_context($_[0][2]);
		if (user_info($check)) {
			my $mask = $_[0][0];
			$mask =~ s/^:[^@]+/*!*/;
			delaycommand("ignore $mask CHAN QUIET");
			command("recv $_[0][0] $_[0][1] $_[0][2] $start<this /names spammer has been ignored: $mask>");
			return EAT_ALL;
		}
	}
	return EAT_NONE;
}

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
