use strict;
use warnings;

# Name:		duplicateenter.pl
# Version:	0.1
# Author:	LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:		2006-06-01
# Description:	Allows Shift+Enter OR Ctrl+Enter to behave the same as a normal Enter

# Note:
# In order to use this script, you will need to add an item to:
#		Settings -> Advanced -> Keyboard Shortcuts
# Create a new item and set the Key to "Return" (hit the enter key while on this obtion)
# In the dropdown box, select "Push input line into history"
# Click either the Ctrl or Shift box (only one) depending on which key want to allow
# (Select Ctrl to use this script unmodified)
#
# Have only one of the two following lines uncommented. The first for Ctrl, the second for Shift
use constant MODIFIER => 20; # Modifier of Ctrl
#use constant MODIFIER => 17; # Modifier of Shift

Xchat::register('Duplicate Enter', '0.1', 'Alows other keys to function as enter via Keyboard Shortcuts');
Xchat::print('Loading Duplicate Enter 0.1');

Xchat::hook_print("Key Press", \&fakeenter);

sub fakeenter {
	if ($_[0][0] == 65293 && $_[0][1] == MODIFIER && Xchat::get_info('inputbox')) {
		my @buffers = split("\012", Xchat::get_info('inputbox'));
		my $commandchar = Xchat::get_prefs('input_command_char');
		foreach my $thisline (@buffers) {
			$thisline = "say $thisline" if ($thisline !~ "^$commandchar");
			Xchat::command($thisline);
		}
	}
	return Xchat::EAT_NONE;
}