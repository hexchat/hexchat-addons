# Name: autoaway.pl
# Version: 1.5
# Author: Raziel
# Date: 2013-05-19
# Description: Automatically /away after a set idle time, server independend timers and away status
#	       Default idle time before /away is 5 minutes, you can change it using /setidletime seconds

# Version History
# 1.0 2013-05-12 Initial Version
# 1.5 2013-05-19 Now server specific

use strict;
use warnings;
use Xchat qw(:all);

my @servers = ();
my @timers = ();
my $idletime = 300000;

register("Raziel", "1.5", 'Automatically /away after a set idle time');

hook_command("SETIDLETIME", \&setIdleTime);
hook_print("Your Message", \&timerCheck);
hook_print("Your Action", \&timerCheck);
hook_print("Connected", \&addNewServer);
populateServers();

sub setIdleTime {
	prnt("Idle time set to ".$_[0][1]." seconds.");
	$idletime = $_[0][1]*1000;
	return EAT_XCHAT;
}

sub timerCheck {
	my $cServ = get_info("server");
	my $pos = posInList(\@servers,$cServ);
	if (defined $timers[$pos]) {
		unhook($timers[$pos]);
	}
	if (defined get_info("away")) {
		setBack($cServ);
	}
	$timers[$pos] = hook_timer($idletime, \&setAway, $cServ);
	return EAT_NONE;
};

sub addNewServer {
	populateServers();
	return EAT_NONE;
}

sub populateServers {
	my @info = get_list("channels");
	foreach my $chan (@info) {
		my $cServ = $chan->{server};
		if (posInList(\@servers,$cServ)==-1) {
			push(@servers,$cServ);
			my $timer = hook_timer($idletime, \&setAway, $cServ);
			push(@timers,$timer);
		}
	}
};

#returns the position in an array of a given element, or -1 if it is not found
#arguments: the array to look in, the element to look for
sub posInList {
	my $pos = -1;
	my @servers = @{$_[0]};
		for (my $cPos = 0; $cPos < scalar(@servers); $cPos++) {
			if ($servers[$cPos] eq $_[1]) {
				$pos = $cPos;
			}
		}
	return $pos;
}

sub setAway {
	my $context = find_context(undef,$_[0]);
	if (!defined context_info($context)->{away}) {
		command("away",undef,$_[0]);
	}
	return REMOVE;
};

sub setBack {
	command("back",undef,$_[0]);
}