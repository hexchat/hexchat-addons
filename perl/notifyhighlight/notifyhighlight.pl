# Name:        notifyhighlight-002.pl
# Version:     002
# Author:      LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:        2010-04-22
# Description: Turn Notify Online and Notify Offline into demi-highlights

# Version History
# 001  2009-10-13 Initial Version
# 002  2010-04-22 Fix an issue with balloon not working on some setups

use strict;
use warnings;
use Xchat qw( :all );

my $NAME    = 'Notify Highlight';
my $VERSION = '002';

register($NAME, $VERSION, 'Turn Notify Online and Notify Offline into demi-highlights');
prnt("Loading $NAME $VERSION");

for my $event ('Notify Online', 'Notify Offline') {
	hook_print($event, \&notify_highlight, { data => $event });
}

sub notify_highlight {
	my $type = ($_[1] eq 'Notify Online' ? 'online' : 'offline');
	my ($nick, $server, $net) = @{$_[0]};
	$net = $server unless $net;

	# why the qq? cause of \ being a valid nick character
	my $message = qq{$nick is $type ($net)};

	command ('gui color 3');
	command ('gui flash') if (get_prefs('input_flash_hilight'));
	command ('tray -i 5') if (get_prefs('input_tray_hilight'));
	command ('tray -t "'.$message.'"') if (get_prefs('input_tray_hilight'));
	command ('tray -b "'.$nick.' '.$type.'" "'.$message.'"') if (get_prefs('input_balloon_hilight'));
	emit_print('Beep') if (get_prefs('input_beep_hilight'));

	return EAT_NONE;
}
