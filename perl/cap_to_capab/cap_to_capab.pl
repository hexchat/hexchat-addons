# Name:		cap_to_capab.pl
# Version:	001
# Author:	LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:		2010-01-29
# Description:	Allow XChat to treat CAP :identify-msg as the CAPAB IDENTIFY-MSG that works in XChat
#		Up through 2.8.6. CAP has more features than just identify-msg, but this script bridges the
#		gap until a new version of XChat is released with full CAP support. identify-msg allows lines
#		to start with a + if the user is identified, and a - if they are not, which XChat interprets
#		as irc_id_ytext and irc_id_ntext.

# Version History
# 001  2010-01-29 Initial Code

use strict;
use warnings;
use Xchat qw(:all);

# on the 005 event, if there is a CLIENTVER=3.0, treat this as the old CAPAB line, but updated
hook_server('005', sub {
	if ($_[1][3] =~/CLIENTVER=3\./) {
		command('CAP REQ :identify-msg');
	}
	return EAT_NONE;
});

# CAP replies create garbage out, but for ACK, check about :identify-msg
hook_server('CAP', sub {
	# there has been a space after identify-msg, but not counting on it
	if ($_[0][3] eq 'ACK' && $_[0][4] eq ':identify-msg') {
		command('recv '.$_[0][0].' 290 '.$_[0][2].' :IDENTIFY-MSG');
		# due to garbage line, eat it!
		return EAT_XCHAT;
	}
	# it may give garbage, but people may still want to see other ACK and LIST
	else {
		return EAT_NONE;
	}
});
