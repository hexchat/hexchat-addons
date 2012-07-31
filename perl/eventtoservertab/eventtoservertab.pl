# Name:		eventtoservertab-001.pl
# Version:	001
# Author:	LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:		2010-05-31
# Description:	Redirect any defined text event to the server tab
# License:	zlib (free to use, attribute me)

# No changes needed within this file
# To add an event, create a "eventtoservertab.conf" in your XChat profile directory.
# For each event you want to send to the server tab, add that event name as a new line
# Event names can be found: Settings -> Advanced -> Text Events

use strict;
use warnings;
use Xchat qw(:all);
use File::Spec;

my @hooks = ();

register('Event to Server Tab', '001', 'Redirect any defined text event to the server tab');

prnt ("Loading \cBEvent to Server Tab 001\cB.");
load_hooks();

hook_command('eventtoservertab', \&load_hooks, { help_text => 'eventtoservertab, reload Event to Server Tab hooks' });
sub to_server_tab {
	# make sure we aren't already in the server tab
	my $tabinfo = context_info;
	return EAT_NONE if context_info->{type} == 1;

	# start out with the base case of if things are smooth, which they may not be
	my $check_context = find_context($tabinfo->{network}, $tabinfo->{server});

	if ( $check_context ) {
		my $checktab = context_info($check_context);
		# the strange case of if the found context is actually a query or something, or a different server id
		undef $check_context if ($checktab->{type} != 1 || $checktab->{id} != $tabinfo->{id});
	}

	# didn't find the correct one? LOOP!
	if ( !$check_context ) {
		my @channels = get_list('channels');
		for (@channels) {
			if ($_->{id} == $tabinfo->{id} && $_->{type} == 1) {
				$check_context = $_->{context};
				last;
			}
		}
	}

	# it still may not be found, in which case nothing will be done, but otherwise, move event
	if ( $check_context ) {
		set_context($check_context);
		emit_print($_[1], @{$_[0]});
		return EAT_ALL;
	}
	else {
		return EAT_NONE;
	}
}

sub load_hooks {
	my $conf_file = File::Spec->catfile(get_info('xchatdir'), 'eventtoservertab.conf');

	unhook $_ foreach @hooks;
	@hooks = (); # clear them if there already!
	my (@errors, @good);

	open (DATA, '<', $conf_file) or do {
		unless (-e $conf_file) {
			prnt 'Configuration file does not exist. Please create '.$conf_file;
		}
		else {
			prnt 'Configuration file could not be read. Please make sure the proper permissions are on '.$conf_file
		}
		return EAT_XCHAT;
	};

	while (<DATA>) {
		s/#.*$//; # remove comments
		s/\s*$//; # remove trailing white space AFTER removing comment
		s/^\s*//; # don't need opening space
		last if (/^__END__$/);
		next if (/^$/); # a blank line!

		# What is provided may not be a text event
		if (defined get_info("event_text $_")) {
			push @hooks, hook_print($_, \&to_server_tab, { data => $_ });
			push @good, $_;
		}
		else {
			push @errors, $_;
		}
	}
	prnt (scalar @good . ' event'.(scalar @good != 1 ? 's' : '').' will be sent to the server tab: '.join('; ', @good));
	prnt ((scalar @errors == 1 ? '1 event does' : scalar @errors .' events do') . ' not match text events: '.join('; ', @errors)) if (@errors);
	return EAT_XCHAT
}
