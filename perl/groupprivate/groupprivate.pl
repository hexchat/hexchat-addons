# Name:        groupprivate-001.pl
# Version:     001
# Author:      LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:        2009-04-28
# Description: Group Private Messages in one window
#              Private messages will only show up if gui_auto_open_dialog is off

# Version History
# 2009-04-28 001 Initial version

use strict;
use warnings;
use Xchat qw(:all);

register('Group Private', '001', 'Group Private Messages in one window');

hook_print($_, \&set_window, { data => $_, priority => PRI_HIGHEST }) foreach('Private Message', 'CTCP Generic', 'Notice');

sub set_window {
	if (get_info('channel') ne $_[0][0] && get_info('channel') ne '{privatemsgs}') {
		unless (set_context('{privatemsgs}', get_info('server'))) {
			command('query {privatemsgs}');
			set_context('{privatemsgs}', get_info('server'));
		}
		emit_print($_[1], @{$_[0]});
		return EAT_ALL;
	}
	return EAT_NONE;
}
