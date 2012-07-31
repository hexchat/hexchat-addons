#!/usr/bin/perl
#
# Name:		chansaver-1.1b.pl
# Version:	1.1b
# Author:	LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:		2007-12-02
# Description:	Allows for Channel Specific settings to be retained (Beep on Message,
#               Show Joins/Parts, Color paste, Blink Tray on Message). Can set default
#               settings based on network, tab name, or both.

# Version Histroy
# 0.1  2006-08-24 The Birth!
# 1.0  2007-11-11 Almost complete rewrite, should be good enough to publish
# 1.1  2007-11-13 Bug fix, make it look right in vi, extra error handling
# 1.2b 2007-12-02 Fixed Help typo, "proper" PODs (no warnings on cheeck)

use strict;
use warnings;
use Xchat qw( :all );

my $CONF_FILE = get_info('xchatdir') . "/chansaver.conf";

my $NAME    = 'Chan Saver';
my $VERSION = '1.1b';

my $CMD = 'chansaver';

=for comment
-- chansaver layout and default menus --
Chan Saver ->
	Save Tab Settings
	Clear Tab Settings
	Set As Default ->
		This Tab Name
		This Network
	Clear Defaults ->
		This Tab Name
		This Network

/menu ADD "Settings/Chan Saver"
/menu -e1 ADD "Settings/Chan Saver/Save Tab Settings" "chansaver save thischan"
/menu -e1 ADD "Settings/Chan Saver/Clear Tab Settings" "chansaver clear thischan"
/menu ADD "Settings/Chan Saver/Set as Default"
/menu -e1 ADD "Settings/Chan Saver/Set as Default/This Tab Name" "chansaver save tab"
/menu -e1 ADD "Settings/Chan Saver/Set as Default/This Network" "chansaver save network"
/menu -e1 ADD "Settings/Chan Saver/Clear Defaults"
/menu -e1 ADD "Settings/Chan Saver/Clear Defaults/This Tab Name" "chansaver clear tab"
/menu -e1 ADD "Settings/Chan Saver/Clear Defaults/This Network" "chansaver clear network"

--switch Cases:--
	CONFMODE:   sswitch($flags & 64)
	COLORPASTE: sswitch($flags & 128)
	BEEP:       sswitch($flags & 256)
	TRAY:       sswitch($flags & 512)

=cut

register($NAME, $VERSION, "Remember channel specific settings to be retained",
	sub { Xchat::command('menu DEL "Settings/Chan Saver"'); } # remove menu on unload
);
Xchat::print("Loading $NAME $VERSION");

hook_command($CMD, \&chansaver, { help_text => 'Usage: ' . get_prefs('input_command_char') . "$CMD refresh, causes all tabs to use settings specified by $NAME" });
#hook_command('chaninfo', \&print_settings); # Debug line if I want it again

hook_print('Open Context', \&load_channel);
hook_print('Focus Tab', \&focus_tab);

my $tabset = load_conf();
load_all_tabs();
load_menu();

# Sub: chansaver; The Catch all command, used for managing the chansaver list and conf
sub chansaver {
	my $target = lc $_[0][2];
	my $method = lc $_[0][1];

	# Early Exit clause if parameters are not correct
	if ( $method eq 'refresh' ) {
		my $context = get_context();
		load_all_tabs();

		set_context($context);
		emit_print('Generic Message', "*$NAME*", 'All channel settings reloaded.');
		return EAT_ALL;
	}
	elsif ( !$target || ($method ne 'save' && $method ne 'clear') ) {
		emit_print('Generic Message', "*$NAME*", "Error: incorrect parameters used. Use \002" . get_prefs('input_command_char') . "$CMD refresh\002 to apply Chan Saver settings to all tabs.");
		return EAT_ALL;
	}

	my %info = context_info();
	my $channel = lc $info{'channel'};
	my $network = lc $info{'network'};

	my $element;
	SWITCH: {
		if ($target eq 'thischan') {
			$element = "$network $channel"; last;
		}
		if ($target eq 'network') {
			$element = "$network *"; last;
		}
		if ($target eq 'tab') {
			$element = "* $channel"; last;
		}
		return;
	}

	if ($method eq 'save') {
		# Three cases to save, thischan, network, channel
		# Time to grab current settings for saving
		my $flags = int context_info()->{'flags'};

		$tabset->{$element}{CONFMODE}   = sswitch($flags & 64);
		$tabset->{$element}{COLORPASTE} = sswitch($flags & 128);
		$tabset->{$element}{BEEP}       = sswitch($flags & 256);
		$tabset->{$element}{TRAY}       = sswitch($flags & 512);
	}
	elsif ($method eq 'clear') {
		delete ($tabset->{$element});
	}

	update_menu($network, $channel);
	write_conf();
}

# load_channel is called when a tab is first loaded into xchat
sub load_channel {
	my %info = context_info();
	my $channel = lc $info{'channel'};
	my $network = lc $info{'network'};

	# Change which Menu options are active due to settings
	# Normally this sub will show if the context is the front one, but to be sure...
	# get_context for current context, find_context for context of front tab
	if ( get_context() == find_context() ) {
		update_menu($network, $channel);
	}

	# This section sets chanopt based on settings
	update_chanopt($network, $channel);
}

# load_all_tabs applies the conf to all open tabs
# mostly used at startup
sub load_all_tabs {
	my $channel; # current channel
	my $network; # current network
	my $thisopt; # setting for chanopt
	
	my @chan_hash = get_list('channels');
	
	foreach my $this_chan (@chan_hash) {
		$channel = lc $this_chan->{'channel'};
		$network = lc $this_chan->{'network'};

		update_chanopt($network, $channel, $this_chan->{'context'});
	}
}

# When the tab changes focus, just need to update the menu
sub focus_tab {
	my %info = context_info();
	my $channel = lc $info{'channel'};
	my $network = lc $info{'network'};

	update_menu($network, $channel);
}

# update_menu gets called from several locations and does just that, updates the Chan Saver menu
sub update_menu {
	my ($network, $channel) = @_;

	if (exists $tabset->{"$network $channel"}) {
		command('menu -e1 ADD "Settings/Chan Saver/Clear Tab Settings" "' . $CMD . ' clear thischan"');
	}
	else {
		command('menu -e0 ADD "Settings/Chan Saver/Clear Tab Settings" "' . $CMD . ' clear thischan"');
	}

	if (exists $tabset->{"$network *"} || exists $tabset->{"* $channel"}) {
		command('menu -e1 ADD "Settings/Chan Saver/Clear Defaults"');
		if (exists $tabset->{"* $channel"}) {
			command('menu -e1 ADD "Settings/Chan Saver/Clear Defaults/This Tab Name" "' . $CMD . ' clear channel"');
		}
		else {
			command('menu -e0 ADD "Settings/Chan Saver/Clear Defaults/This Tab Name" "' . $CMD . ' clear tab"');
		}
		if (exists $tabset->{"$network *"}) {
			command('menu -e1 ADD "Settings/Chan Saver/Clear Defaults/This Network" "' . $CMD . ' clear network"');
		}
		else {
			command('menu -e0 ADD "Settings/Chan Saver/Clear Defaults/This Network" "' . $CMD . ' clear network"');
		}
	}
	else {
		command('menu -e0 ADD "Settings/Chan Saver/Clear Defaults"');
	}
}

# update_chanopt updates the chanopt settings for a provided tab using $tabset
sub update_chanopt {
	my ($network, $channel, $context) = @_;
	my $thisopt;

	if (exists $tabset->{"$network $channel"}) { $thisopt = $tabset->{"$network $channel"}; }
	elsif (exists $tabset->{"* $channel"}) { $thisopt = $tabset->{"* $channel"}; }
	elsif (exists $tabset->{"$network *"}) { $thisopt = $tabset->{"$network *"}; }
	else { return; }

	set_context($context) if $context;

	# now load the settings!
	command("chanopt confmode $thisopt->{CONFMODE}")     if $thisopt->{CONFMODE};
	command("chanopt colorpaste $thisopt->{COLORPASTE}") if $thisopt->{COLORPASTE};
	command("chanopt beep $thisopt->{BEEP}")             if $thisopt->{BEEP};
	command("chanopt tray $thisopt->{TRAY}")             if $thisopt->{TRAY};
}

=for comment
#debug sub here, I may want it again
sub print_settings {
	my $flags = int Xchat::context_info()->{'flags'};

	Xchat::print 'Conference: ' . sswitch($flags & 64) . '; Color Paste: ' . sswitch($flags & 128) . '; Beep: ' . sswitch($flags & 256) . '; Tray: ' . sswitch($flags & 512); 
}

=cut

# The conf file is rather simple, and so the conf file is as well. Returns a hash reference
# used on startup, don't think I will use it after script is loaded
sub load_conf {
	my %tabhash = ();
	my @words = ();
	my $tmpchan, my $tmpnet;

	open (DATA, '<', $CONF_FILE) or do {
		my $message;

		unless (-e $CONF_FILE) {
			$message = 'Configuration file does not exist. A new configuration file will be created.';
		}
		elsif ( !(-r $CONF_FILE) ) {
			$message = "Unable to read \002$CONF_FILE\002. Please make sure you have proper permission for this file.";
		}
		else {
			$message = "Unknown problem encountered reading \002$CONF_FILE\002. Changes made may not be saved (or perhaps they will).";
		}

		emit_print('Generic Message', "*$NAME*", $message);
		return \%tabhash;
	};

	foreach(<DATA>) {
		@words = split /\s+/;
		next unless ($words[1]); #if the line doesn't have at least 2 words, skip
		
		if ($words[0] eq 'TAB' && $words[1] && $words[2]) {
			$tmpnet  = $words[1];
			$tmpchan = $words[2];
		}
		elsif ($tmpnet && $tmpchan && $_ =~ /(CONFMODE|COLORPASTE|BEEP|TRAY).*(ON|OFF)/i) {
			$tabhash{"$tmpnet $tmpchan"}{uc $1} = uc $2;
		}
	}
	close(DATA);

	return \%tabhash;
}

sub write_conf {
	open (DATA, '>', $CONF_FILE) or do {
		emit_print('Generic Message', "*$NAME*", "Unable to write to $CONF_FILE");
		return EAT_ALL;
	};

	print DATA "# $NAME $VERSION Configuration file\n";
	print DATA "# This file is automatically generated and may not retain changes made to it\n";

	while ( my ($tab_ref, $inhash) = each %$tabset ) {
		print DATA "\nTAB $tab_ref\n";
		for my $option ( sort keys %$inhash ) {
			print DATA "$option $inhash->{$option}\n";
		}
	}
	close (DATA);
}

# basic bit to load the menu initally. May change in time
sub load_menu {
	my $base_menu = <<BASE_MENU;
menu ADD "Settings/Chan Saver"
menu -e1 ADD "Settings/Chan Saver/Save Tab Settings" "$CMD save thischan"
menu -e0 ADD "Settings/Chan Saver/Clear Tab Settings" "$CMD clear thischan"
menu ADD "Settings/Chan Saver/Set as Default"
menu -e1 ADD "Settings/Chan Saver/Set as Default/This Tab Name" "$CMD save tab"
menu -e1 ADD "Settings/Chan Saver/Set as Default/This Network" "$CMD save network"
menu -e0 ADD "Settings/Chan Saver/Clear Defaults"
menu -e0 ADD "Settings/Chan Saver/Clear Defaults/This Tab Name" "$CMD clear tab"
menu -e0 ADD "Settings/Chan Saver/Clear Defaults/This Network" "$CMD clear network"
BASE_MENU

	chomp (my @menu_array = split(/^/,$base_menu));
	foreach my $menu_item (@menu_array) {
		command($menu_item);
	}

	# This bit makes sure that the current focused tab is updated
	set_context(find_context());
	focus_tab();
}

# sswitch: simply return ON for true and OFF for false
sub sswitch {
	return ($_[0] ? 'ON' : 'OFF');
}