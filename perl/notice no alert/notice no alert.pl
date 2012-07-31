# Name:        notice_no_alert-001.pl
# Version:     001
# Author:      LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:        2010-07-04
# Description: Make notices not follow "Private Message" alert rules
#              All options will be as if turned off
# License:     zlib (free to use, attribute LifeIsPain)

use strict;
use warnings;
use Xchat qw(:all);

register('Notice No Alert', '001', 'Make notices not follow "Private Message" alert rules');

hook_server('NOTICE', sub {
	my $turn_back_on = [];
	foreach('input_balloon_priv', 'input_flash_priv', 'input_tray_priv', 'input_beep_msg') {
		if (get_prefs($_)) {
			push (@{$turn_back_on}, $_);
			command("set -quiet $_ 0");
		}
	}
	if (scalar @{$turn_back_on}) {
		hook_timer(0, sub {
			command("set -quiet $_ 1") foreach (@{$turn_back_on});
			return REMOVE;
		});
	}
	return EAT_NONE;
});
