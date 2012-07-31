# Name:        doop
# Version:     002
# Author:      LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:        2011-12-16
# Description: Optain op, and do some stuff when all done
# License:     zlib (details at end of file)

# Version History at end of file

use strict;
use warnings;
use Xchat qw(:all);

register ("Do Op", "002", "Obtain op and then run a command");

hook_command("doop", \&doop_command, { help_text => 'doop [{+|-}{v|o|h|q|b} <nick or mask>] [-d] <command>, Op yourself with chanserv, run a command'});
hook_command("remove", \&remove_command, { help_text => 'remove  [-r "<reason>"] [-b] <nick1> <nick2>, remove a group of users, optionally banning'});

my %conf = (
	command_timeout => 240, # number of seconds before not running command
	deop_time => 0, # number of seconds to wait before default deop
);

my $context_queue = {};
my $op_check_hook;
my $chanserv_hook;

# /doop [--c #channel] [-d (deop when done)] <command>
sub doop_command {
	my $i = 1;
	my $to_channel;
	my $deop = -1;
	my $command;
	my $predefined_lists = {
		'+' => {},
		'-' => {},
	};
	my $error;
	my $deop_time = $conf{deop_time};

	PARAMETER: while ($_[0][$i]) {
		# specify a channel, with or without an = separator
		if (lc $_[0][$i] eq '--c' || lc $_[0][$i] eq '--channel') {
			$to_channel = $_[0][$i+1] if defined $_[0][$i+1];
			$i = $i+2;
		}
		elsif ($_[0][$i] =~ /^--c(?:hannel)?=(.+)/i) {
			$to_channel = $1;
			$i++;
		}
		# remove op when done, no parameter
		elsif (lc $_[0][$i] =~ /^-d(\d+)?$/) {
			$deop = ($1 ? $1 : 0);
			$i++;
		}
		# allow for syntax to auto voice, hop, op, ban, quiet
		elsif ($_[0][$i] =~ /^(?:[+\-][vhobq]+)+$/) {
			my @mode_parts = split('', $_[0][$i]);
			my $sign;
			foreach (@mode_parts) {
				if ($_ eq '+' || $_ eq '-') {
					$sign = $_;
				}
				else {
					if (defined $_[0][$i+1] && $_[0][$i+1] !~ m/^[+\-]/) {
						push(@{$predefined_lists->{$sign}{$_}}, $_[0][$i+1]);
						$i++;
					}
					# error out and end if not provided correctly
					else {
						$error = 'Parameter "' . join('', @mode_parts) . '" used without enough sequential paremeters.';
						last PARAMETER;
					}
				}
			}
			$i++;
		}
		# catch errors
		elsif ($_[0][$i] =~ /^[+\-]/) {
			$error = 'Unknown Parameter: '.$_[0][$i];
			last;
		}
		else {
			$command = $_[1][$i];
			last;
		}
	}

	# don't do anything if there was an error
	if (defined $error) {
		prnt $error;
	}
	else {
		do_commands($to_channel, $deop, $command, $predefined_lists)
	}

	return EAT_XCHAT;
}

# get the commands ready, and if op do
sub do_commands ($$$$) {
	my ($channel, $deop, $command, $predefined_lists) = @_;
	my $context;
	my @commands;

	# determine context for channel
	if (defined $channel) {
		$context = find_context($channel);
	}
	else {
		$context = get_context;
		$channel = get_info('channel');
	}

	# if there is no context, or the context isn't a channel, say so
	if (!defined $context || context_info($context)->{type} != 2) {
		prnt ("$channel is not a channel.");
		return;
	}

	# set context if it was passed
	set_context($context);

	# convert the pre-defined commands into a command list
	my $this_mode_count = 0;
	my $this_mode = '';
	my @this_mode_params = ();
	my $max_modes = context_info->{'maxmodes'};
	my $lastsign = '+';
	foreach my $sign ('+', '-') {
		foreach my $mode (keys %{$predefined_lists->{$sign}}) {
			foreach (@{$predefined_lists->{$sign}{$mode}}) {
				$this_mode = $sign if ($this_mode_count == 0);
				if ($sign ne $lastsign) {
					$this_mode .= $sign;
					$lastsign = $sign;
				}
				$this_mode .= $mode;
				push (@this_mode_params, $_);
				$this_mode_count++;
				# make a command if all filled out
				if ($this_mode_count == $max_modes) {
					push (@commands, [time, "mode $this_mode ".join(' ', @this_mode_params), 0]);
					$this_mode_count = 0;
					$this_mode = '';
					@this_mode_params = ();
				}
			}
		}
	}

	# add deop to the mode line unless a command is provided, and deop is 0
	if ($deop == 0 && !defined $command) {
		if ($this_mode_count != 0) {
			$this_mode .= '-o';
			push (@this_mode_params, get_info('nick'));
			$deop = -1;
		}
	}
	# add command for the left over modes
	if ($this_mode_count != 0) {
		push (@commands, [time, "mode $this_mode ".join(' ', @this_mode_params), 0]);
	}

	# now add the command
	push (@commands, [time, $command, 0]) if (defined $command);

	# still have a deop left? Do it after the command
	if ($deop != -1) {
		push (@commands, [time, "mode -o ".get_info('nick'), $deop]);
	}

	# if already an op, great, do stuff (allows for anything other than + in the mode, for halfops and higher)
	if (user_info->{prefix} && user_info->{prefix} ne '+') {
		foreach (@commands) {
			delaycommand($_->[1], $_->[2]);
		}
	}
	# otherwise, get it going
	else {
		unless (defined $op_check_hook) {
			setup_op_check();
		}
		unless (defined $context_queue->{$context}) {
			command("QUOTE CS op $channel");
		}
		push (@{$context_queue->{$context}}, @commands);
	}
}

sub setup_op_check {
	# It will either be a 'Channel Operator' event, or a 'Raw Modes' event, depending
	if (get_prefs('irc_raw_modes')) {
		$op_check_hook = hook_print('Raw Modes', sub {
			# only have to worry about op of a single nick, me
			if ($_[0][1] =~ /^#\S+ \+o (\S+)$/ && nickcmp($1, get_info('nick')) == 0) {
				run_when_opped();
			}
		});
	}
	else {
		$op_check_hook = hook_print('Channel Operator', sub {
			if (nickcmp($_[0][1], get_info('nick')) == 0) {
				run_when_opped();
			}
		});
	}

}

sub run_when_opped {
	my $sub_context = get_context;
	if (defined $context_queue->{$sub_context}) {
		foreach (@{$context_queue->{$sub_context}}) {
			delaycommand($_->[1], $_->[2]) if (time - $_->[0] <= $conf{command_timeout});
		}
		delete $context_queue->{$sub_context};
		if (keys %$context_queue == 0) {
			unhook $op_check_hook;
			undef $op_check_hook;
		}
	}
}

# delaycommand, best sub! Allow for delays in seconds
sub delaycommand {
	my $command = $_[0];
	my $delay = ($_[1] ? $_[1]*1000 : 0);
	hook_timer( $delay,
		sub {
			command($command);
			return REMOVE;
		}
	);
	return EAT_NONE;
}

__END__

Version History:
001  2011-12-10 Initial Code
002  2011-12-16 Allow for timed deop, extra error checks,
		mode paste syntax (-bbbb) for non command portion,
		considers anything higher than mode + to be op like

Todo:
Command Syntax inline items such as kick and remove

Known Issues:
If you change irc_raw_modes while there are pending ops, they won't show up, have to reload script
- Enough of corner case, ignoring, most people set that option and forget it (or never set it)

License:
Copyright (c) 2011 Brian Evans

doop is provided 'as-is', without any express or implied warranty. In no
event will the authors be held liable for any damages arising from the
use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must not
   claim that you wrote the original software. If you use this software
   in a product, an acknowledgment in the product documentation would be
   appreciated but is not required.

2. Altered source versions must be plainly marked as such, and must not
   be misrepresented as being the original software.

3. This notice may not be removed or altered from any source
   distribution.
