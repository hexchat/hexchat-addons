# Name:        showmodedate.pl
# Version:     001
# Author:      LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:        2010-01-18
# Description: Show the channel creation time when doing /mode on a channel you aren't on
#              (due to silly exception in source)

# Version History
# 001  2010-01-18 Initial Version for someone in #xchat

use strict;
use warnings;
use Xchat qw(:all);

#:irc.server.net 329 YourUser #channel 1247789854
hook_server('329', sub {
	unless (find_context($_[0][3], get_info('server'))) {
		emit_print('Channel Creation', $_[0][3], scalar localtime($_[0][4]));
	}
	return EAT_NONE;
});
