# Name:		showallchannels-001.pl
# Version:	001
# Author:	LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:		2010-02-04
# Description:	Show all messages from all channels in a separate tab

# Version History
# 001  2010-02-04 Initial Code, pulled from showhighlight-2.2.pl

# No changes needed within this file

use strict;
use warnings;
use Data::Dumper;
use File::Spec;
use Xchat qw(:all);

my $version = '001';
my $name = 'Show All Channels';

# Documentation of settings
#   All changes are made using /sc_set [-q] [-e] <variable> [value]
#  append_channel : 1 or 0, if "/#channlename" should be added after the nick
#  append_string  : The string to use before "#channelname" (default is /)
#  message_tab    : The string to use as a glob tab, no double quotes (")
#  shared_tab     : 1 or 0, if 1, all networks will use a common glob tab
#  quiet_manage   : 1 or 0, if 1, the options in the right click won't announce changes
#  gui_manage     : 1 or 0, if 0, the normal right click menu won't have options

my $DEFAULTS = {
	'append_channel' => 1,
	'append_string' => '/',
	'message_tab' => 'all chans',
	'shared_tab' => 1,
	'quiet_manage' => 0,
	'gui_manage' => 1,
	'ignore_channels' => [],
	'ignore_nicks' => [],
};

register($name, $version, 'Shows Highlighted messages in a special window.', \&del_menu);
prnt("Loading $name $version");

for my $event ('Channel Msg Hilight', 'Channel Action Hilight', 'Channel Action', 'Channel Message', 'Your Message', 'Your Action') {
	hook_print($event, \&catch_all, { data => $event });
}

hook_command('sc_chanignore', \&cmd_sc_chanignore, { help_text => 'sc_chanignore [-q] <#channel>, add #channel to the Show All Channels ignore list'});
hook_command('sc_chanallow', \&cmd_sc_chanallow, { help_text => 'sc_chanallow [-q] <#channel>, remove #channel from the Show All Channels ignore list'});
hook_command('sc_nickignore', \&cmd_sc_nickignore, { help_text => 'sc_nickignore [-q] <nick>, add nick to the Show All Channels ignore list'});
hook_command('sc_nickallow', \&cmd_sc_nickallow, { help_text => 'sc_nickallow [-q] <nick>, remove nick from the Show All Channels ignore list'});
hook_command('sc_set', \&cmd_sc_set, { help_text => 'sc_set [-q] [-e] [<variable>] [<value>], list or change settings for Show All Channels script'});

my $CONF;
my $conf_file = File::Spec->catfile(get_info('xchatdir'), 'showallchannels.conf');

# this will behave much as /set
sub cmd_sc_set {
	my $i = 1;
	my $quiet = 0;
	my $erase = 0;
	my ($variable, $value);

	while ($_[0][$i]) {
		if (lc $_[0][$i] =~ /^-q/) { # meh, match -q and -quiet
			$quiet = 1;
			$i++;
		}
		elsif (lc $_[0][$i] eq '-e') {
			$erase = 1;
			$i++;
		}
		else {
			$variable = lc $_[0][$i];
			$value = $_[1][$i+1] if defined $_[1][$i+1];
			last;
		}
	}

	# list available options if need be (as in, no extra param)
	unless (defined $value || $erase) {
		my @keys;
		unless ($variable) {
			@keys = sort keys %$CONF;
		}
		else {
			# turn that key into a simple string for matching
			$variable = '^'. $variable . '$';
			$variable =~ s/\*/.*/g;
			@keys = grep(/$variable/, sort keys %$CONF);
		}

		foreach(@keys) {
			# special case of ignore_nicks and ignore_channels
			if ($_ eq 'ignore_nicks' || $_ eq 'ignore_channels') {
				$value = join(', ', @{$CONF->{$_}});
			}
			else {
				$value = $CONF->{$_};
			}
			prnt $_ . '.' x (29-length $_).': '. $value;
		}
		unless (scalar @keys) {
			prnt 'No such variable.';
		}
	}

	elsif (exists $CONF->{$variable}) {
		if ($erase) {
			# a few special cases
			# append_string actually can be blank
			if ($variable eq 'append_string') {
				$CONF->{$variable} = '';
				$value = '';
			}
			# some will just revert to defauts on -e
			elsif (defined $DEFAULTS->{$variable}) {
				$CONF->{$variable} = $DEFAULTS->{$variable};
				# sometimes, the default is an array ref
				if (ref($DEFAULTS->{$variable}) eq 'ARRAY') {
					$value = join(', ', @{$DEFAULTS->{$variable}});
				}
				else {
					$value = $DEFAULTS->{$variable};
				}
			}
			else {
				$CONF->{$variable} = undef;
				$value = '';
			}
		}
		else {
			my $update_menu = 0;
			# a few special cases
			if (ref($DEFAULTS->{$variable}) eq 'ARRAY') {
				# split and sort, then rejoin for display!
				$CONF->{$variable} = [ sort split (/,\s*/, $value) ];
				$value = join(', ', @{ $CONF->{$variable} });
			}
			# everything else is a scalar, so will change the conf at the end
			else {
				# message_tab can't have double quotes
				if ($variable eq 'message_tab') {
					$value =~ s/"//g;
					$CONF->{$variable} = $value;
				}
				# some, we want only integers
				elsif ($variable eq 'append_channel' || $variable eq 'shared_tab' || $variable eq 'quiet_manage' || $variable eq 'gui_manage') {
					$value = 1 if $value =~ /^on/i;
					$value = 0 if $value =~ /^off/i;
					# really make sure it is an integer
					$value =~ s/^.*?(-?\d+).*/$1/g;
					$value = int $value;
					
					# quiet_manage and gui_manage need settings changed
					if ($variable eq 'quiet_manage' || $variable eq 'gui_manage') {
						$update_menu = 1 if $value != $CONF->{$variable};
					}
				}
				# update that conf!
				$CONF->{$variable} = $value;
			}

			# more with the quiet_manage and gui_manage
			if ($update_menu) {
				del_menu();
				add_menu();
			}
		}
		
		unless ($quiet) {
			prnt $variable.' set to: '.$value;
		}
		
		# save that sucker!
		save_conf();
	}
	elsif (!$quiet) {
		prnt 'No such variable.';
	}
	return EAT_XCHAT;
}

sub catch_all {
	my @msgdata = @{$_[0]};
	my $event = $_[1];

	# leave now if the nick is to be ignored
	# strip codes on nick, due to colored nicks
	my $cmpnick = strip_code($msgdata[0]);
	foreach (@{ $CONF->{ignore_nicks} }) {
		return EAT_NONE if (nickcmp($_, $cmpnick) == 0);
	}

	# Next leave if one of the channels is ignored
	my $channel = get_info('channel');
	foreach (@{ $CONF->{ignore_channels} }) {
		return EAT_NONE if (nickcmp($_, $channel) == 0);
	}

	my $orig_context = get_context();

	# default setting is to append channel, can be changed with setting
	if ($CONF->{append_channel}) { $msgdata[0] .= $CONF->{append_string} . $channel; }

	# Two cases, first for when each network has own message tab, second for share
	# Each case uses appropriate set_context, and if that fails, create tab, and set
	# the context to the newly created tab
	if ( ! $CONF->{shared_tab} && ! set_context($CONF->{message_tab}, get_info('server')) ) {
		command('QUERY "'.$CONF->{message_tab}.'"');
		# don't need logging, and don't need scrollback, but only do this if the set_context passes (which it better!)
		if (set_context($CONF->{message_tab}, get_info('server'))) {
			command('chanopt -quiet text_logging off');
			command('chanopt -quiet text_scrollback off');
		}
	}
	elsif ( $CONF->{shared_tab} && ! set_context($CONF->{message_tab}) ) {
		command('NEWSERVER -noconnect "'.$CONF->{message_tab}.'"');
		if (set_context($CONF->{message_tab})) {
			command('chanopt -quiet text_logging off');
			command('chanopt -quiet text_scrollback off');
		}
	}

	prnt( format_event($event, @msgdata) );

	set_context($orig_context);

	return EAT_NONE;
}

# Convert Text Events with data into just a string which is returned
#   usage: format_event("Channel Message", @arrayofargs)
sub format_event {
	# Expect up to 5 events (that is what text.c goes up to)
	my ($event, @items) = @_;
	$#items = 4; # force there to be 4 items

	# Future regex has problems if a string doesn't exist
	foreach (@items) {
		$_ = '' unless $_;
	}

	my $string = get_info('event_text ' . $event);

	# Do the static macro replacements
	$string = macro_fill($string);

	# Actually replace the $s
	$string =~ s/\$1/$items[0]/g;
	$string =~ s/\$3/$items[2]/g;
	$string =~ s/\$4/$items[3]/g;
	$string =~ s/\$2/$items[1]/g; # $2 may actually have $1, $3, or $4 in it, so do it last

	return $string;
}

# sub for macro replacement using ///e regex
#   usage: s/%(.)/macro_sub $1/eg
sub macro_sub ($) {
	if    ($_[0] eq 'U') { return "\c_"; }
	elsif ($_[0] eq 'B') { return "\cB"; }
	elsif ($_[0] eq 'C') { return "\cC"; }
	elsif ($_[0] eq 'O') { return "\cO"; }
	elsif ($_[0] eq 'R') { return "\cV"; }
	elsif ($_[0] eq 'H') { return "\cH"; }
	elsif ($_[0] eq '%') { return '%';   }
	return '%'.$_[0];
}

sub macro_fill {
	$_[0] =~ s/%(.)/macro_sub $1/eg;
	$_[0] =~ s/\$t/\t/;
	return ($_[0]);
}

# add new nicks to ignore event on to list
sub cmd_sc_nickignore {
	my ($cmd, @args) = @{$_[0]};
	my $quiet = ($args[0] && lc $args[0] eq '-q' ? 1 : 0);
	shift @args if $quiet;

	if ($args[0]) {
		#make sure it isn't in here already
		my $found = 0;
		foreach (@{ $CONF->{ignore_nicks} }) {
			$found = 1 if (nickcmp($_, $args[0]) == 0);
		}
		unless ($found) {
			# lets make it sorted for print purposes
			$CONF->{ignore_nicks} = [sort (@{$CONF->{ignore_nicks}}, $args[0])];
			save_conf();
		}
		# lets give some status errors unless quiet
		if (!$quiet) {
			if ($found) {
				message_print("Messages from $args[0] previously ignored for Show All Channels");
			}
			else {
				message_print("Messages from $args[0] now ignored for Show All Channels");
			}
		}
	}
	return EAT_XCHAT;
}

# remove nicks from ignore event list
sub cmd_sc_nickallow {
	my ($cmd, @args) = @{$_[0]};
	my $quiet = ($args[0] && lc $args[0] eq '-q' ? 1 : 0);
	shift @args if $quiet;

	if ($args[0]) {
		#make sure it is actually here
		my $found = 0;
		my $i = 0;
		while ($i < scalar @{ $CONF->{ignore_nicks} }) {
			if (nickcmp($CONF->{ignore_nicks}[$i], $args[0]) == 0) {
				splice( @{ $CONF->{ignore_nicks} }, $i, 1 );
				$found = 1;
				save_conf();
				last;
			}
			else {
				$i++;
			}
		}
		# lets give some status errors unless quiet
		if (!$quiet) {
			if ($found) {
				message_print("Messages from $args[0] no longer ignored for Show All Channels");
			}
			else {
				message_print("Messages from $args[0] had not been ignored for Show All Channels");
			}
		}
	}
	return EAT_XCHAT;
}

# add new chans to ignore event on to list
sub cmd_sc_chanignore {
	my ($cmd, @args) = @{$_[0]};
	my $quiet = ($args[0] && lc $args[0] eq '-q' ? 1 : 0);
	shift @args if $quiet;

	if ($args[0]) {
		#make sure it isn't in here already
		my $found = 0;
		foreach (@{ $CONF->{ignore_channels} }) {
			$found = 1 if (nickcmp($_, $args[0]) == 0);
		}
		unless ($found) {
			# lets make it sorted for print purposes
			$CONF->{ignore_channels} = [sort (@{$CONF->{ignore_channels}}, $args[0])];
			save_conf();
		}
		# lets give some status errors unless quiet
		if (!$quiet) {
			if ($found) {
				message_print("Messages on $args[0] previously ignored for Show All Channels");
			}
			else {
				message_print("Messages on $args[0] now ignored for Show All Channels");
			}
		}
	}
	return EAT_XCHAT;
}

# remove chans from ignore event list
sub cmd_sc_chanallow {
	my ($cmd, @args) = @{$_[0]};
	my $quiet = ($args[0] && lc $args[0] eq '-q' ? 1 : 0);
	shift @args if $quiet;

	if ($args[0]) {
		#make sure it is actually here
		my $found = 0;
		my $i = 0;
		while ($i < scalar @{ $CONF->{ignore_channels} }) {
			if (nickcmp($CONF->{ignore_channels}[$i], $args[0]) == 0) {
				splice( @{ $CONF->{ignore_channels} }, $i, 1 );
				$found = 1;
				save_conf();
				last;
			}
			else {
				$i++;
			}
		}
		# lets give some status errors unless quiet
		if (!$quiet) {
			if ($found) {
				message_print("Messages on $args[0] no longer ignored for Show All Channels");
			}
			else {
				message_print("Messages on $args[0] had not been ignored for Show All Channels");
			}
		}
	}
	return EAT_XCHAT;
}

# Save the conf. Use Data::Dumper to serialize it, as is Core Module
sub save_conf {
	open (DATA, '>'.$conf_file);
	print DATA '# '.$name.' '.$version." configruation file\n# This file is automatically generated and may be replaced\n\n";
	$Data::Dumper::Indent = 1;
	print DATA Data::Dumper->Dump([$CONF], [qw(CONF)]);

	close DATA;
}

# load the configuration to $CONF
sub load_conf {
	if (-e $conf_file) {
		unless ($CONF = do $conf_file) {
			prnt "Couldn't parse $conf_file: $@" if $@;
			prnt "Couldn't do $conf_file: $!"    unless defined $CONF;
			prnt "Couldn't run $conf_file"       unless $CONF;
		}
	}
	else {
		message_print("Configuration file does not exist. Will be created when needed.");
	}

	# set the defaults if they aren't there
	foreach (keys %$DEFAULTS) {
		$CONF->{$_} = $DEFAULTS->{$_} unless defined $CONF->{$_}
	}
}

# generic message print, has a delay for after hook_prints
sub message_print {
	my $message = $_[0];
	hook_timer( 10,
		sub {
			emit_print('Generic Message', '*Show All Chans*', $message);
			return REMOVE;
		}
	);
}

# add the menu items
sub add_menu {
	if ($CONF->{gui_manage}) {
		command('timer 1 menu ADD "$NICK/Show In Glob" "sc_nickallow'.($CONF->{quiet_manage} ? ' -q ' : ' ').'%s"');
		command('timer 1 menu ADD "$NICK/Ignore In Glob" "sc_nickignore'.($CONF->{quiet_manage} ? ' -q ' : ' ').'%s"');
		command('timer 1 menu ADD "$CHAN/Show In Glob" "sc_chanallow'.($CONF->{quiet_manage} ? ' -q ' : ' ').'%s"');
		command('timer 1 menu ADD "$CHAN/Ignore In Glob" "sc_chanignore'.($CONF->{quiet_manage} ? ' -q ' : ' ').'%s"');
	}
}

# User Menu items were added, remove them
sub del_menu {
	command('menu DEL "$NICK/Show In Glob"');
	command('menu DEL "$NICK/Ignore In Glob"');
	command('menu DEL "$CHAN/Show In Glob"');
	command('menu DEL "$CHAN/Ignore In Glob"');
}

load_conf();
add_menu();
