# Name:        servernoticejqtab.pl
# Version:     001
# Author:      LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:        2010-01-20
# Description: Separates Server Notices for Join and Part as seen by Undernet IRCOPS
#              Script has no use for non ircops, as most people don't see the notices when
#                a user joins and quits the network.
#              If the user is G-lined, the quit message does not change tabs

# Version History
# 001  2010-01-20 Initial Version for somebody in #xchat

use strict;
use warnings;
use Xchat qw (:all);

register('Server Notice JQ', '001', 'Set Server Notice Join Parts to a separate tab');

# change the next line to have the tab named something else
my $tabname = '(Client snotices)';


my $lastgline = ''; # not that I like globals, but meh, easier this way

hook_print('Server Notice', sub {
	unless (get_info('channel') eq $tabname) {
		# if it is a gline, set the $lastgline to the nick, so as to leave that client exiting with other snotices
		if ($_[0][0] =~ /^G-line active for ([^\[]+)/) {
			$lastgline = $1;
		}
		# Well, just want lines that start with Client *, except for Client exiting due to gline
		elsif ($_[0][0] =~ /^Client / && $_[0][0] !~ /^Client exiting: $lastgline /) {
			# so user wants the connecting ones to start with a bold
			my @events = @{$_[0]};
			$events[0] = "\002".$events[0] if ($events[0] =~ /^Client connecting/);
			unless (set_context($tabname, $_[0][1])) {
				command("query \"$tabname\"");
				set_context($tabname, $_[0][1]);
			}
			emit_print('Server Notice', @events);
			return EAT_ALL;
		}
	}
	return EAT_NONE;
});
