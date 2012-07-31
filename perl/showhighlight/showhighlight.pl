# Name:		showhighlight-3.3.pl
# Version:	3.3
# Author:	LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:		2011-08-30
# Description:	Show highlighted messages in a seperate tab
# License:	zlib (attribute me, free to use for whatever)

# Version History at end of file

# No changes needed within this file

use strict;
use warnings;
use Data::Dumper;
use File::Spec;
use Xchat qw(:all);
use POSIX qw(strftime);

my $version = '3.3';
my $name = 'Show Highlight';

=begin documentation
Documentation of settings
   All changes are made using /sh_set [-q] [-e] <variable> [value]
	nick_format    : What should be used for nick formating, for additional details
	msg_format     : what should be used for message formating, similar to above
			Both nick_format and msg_format can use:
				%channel%          : name of the channel
				%network%          : name of the network based on resolve_type
				%network_list%     : network as specified in network list
				%network_server%   : actual server name
				%network_reported% : network as returned by server on connect (sometimes)
				%timestamp%        : timestamp as specified in Preferences > Text box
				%nick%             : user who said the line (default of nick_format)
				%message%          : actual message said (default of msg_format)
	color_tab      : -1 - 3, What color to change the tab to
			-1) new data (unless something higher, default); 0) visited; 1) new data;
			2) new message; 3) new highlight
	highlight_tab  : The string to use as a highlight tab, no double quotes (")
	shared_tab     : 0, 1, or 2, 0 is no sharing (highlight only), 1 is shared with other
	                 networks, 2 is shared with the server tab
	quiet_manage   : 1 or 0, if 1, the options in the right click won't announce changes
	gui_manage     : 1 or 0, if 0, the normal right click menu won't have options
	resolve_type   : How should %network% be resolved in order:
			1) As specified in network list, as reported by server, server address
			2) As specified in network list, server address
			3) As reported by server, as specified in network list, server address
			4) As reported by server, server address
=end documentation
=cut

use constant {
	TYPE_STRING => 1,
	TYPE_BOOL => 2,
	TYPE_INT => 3,
	TYPE_ARRAY => 4
};

my $DEFAULTS = {
	'nick_format' => ['%nick%/%channel%', TYPE_STRING],
	'msg_format' => ['%message%', TYPE_STRING],
	'color_tab' => [-1, TYPE_INT],
	'highlight_tab' => [':highlight:', TYPE_STRING],
	'shared_tab' => [1, TYPE_INT],
	'quiet_manage' => [0, TYPE_BOOL],
	'gui_manage' => [1, TYPE_BOOL],
	'ignore_nicks' => [[], TYPE_ARRAY],
	'resolve_type' => [1, TYPE_INT],
};

register($name, $version, 'Shows Highlighted messages in a special window.', \&del_menu);
prnt("Loading $name $version");

for my $event ('Channel Msg Hilight', 'Channel Action Hilight') {
	hook_print($event, \&msg_highlight, { data => $event });
}

hook_command('sh_ignore', \&cmd_sh_ignore, { help_text => 'sh_ignore [-q] <nick>, add nick to the Show Highlight ignore list'});
hook_command('sh_allow', \&cmd_sh_allow, { help_text => 'sh_allow [-q] <nick>, remove nick from the Show Highlight ignore list'});
hook_command('sh_set', \&cmd_sh_set, { help_text => 'sh_set [-q] [-e] [<variable>] [<value>], list or change settings for Show Highlight script'});

my $CONF;
my $conf_file = File::Spec->catfile(get_info('xchatdir'), 'showhighlight.conf');

# this will behave much as /set
sub cmd_sh_set {
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
			# special case of arrays
			if ($DEFAULTS->{$_}[1] == TYPE_ARRAY) {
				$value = join(', ', @{$CONF->{$_}});
			}
			elsif ($DEFAULTS->{$_}[1] == TYPE_BOOL) {
				$value = $CONF->{$_} ? 'on' : 'off';
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

	elsif (defined $variable && exists $CONF->{$variable}) {
		my $oldvalue = $CONF->{$variable};
		if ($erase) {
			# not really erasing, setting to default
			$CONF->{$variable} = $DEFAULTS->{$variable}[0];
		}
		else {
			# a few special cases
			if ($DEFAULTS->{$variable}[1] == TYPE_ARRAY) {
				# split and sort, then rejoin for display!
				$CONF->{$variable} = [ sort split (/,\s*/, $value) ];
			}
			# highlight_tab can't have double quotes
			elsif ($variable eq 'highlight_tab') {
				$value =~ s/"//g;
				$CONF->{$variable} = $value;
			}
			# some, we want only booleans
			elsif ($DEFAULTS->{$variable}[1] == TYPE_BOOL) {
				if ($value =~ /^of|^f/i || !$value) {
					$CONF->{$variable} = 0;
				}
				else {
					$CONF->{$variable} = 1;
				}
			}
			# and other times ints
			elsif ($DEFAULTS->{$variable}[1] == TYPE_INT) {
				# really make sure it is an integer
				$value =~ s/^.*?(-?\d+).*/$1/g;
				# update that conf!
				$CONF->{$variable} = int $value;
			}
			# no special cases, set it!
			else {
				$CONF->{$variable} = $value;
			}
		}
		
		unless ($quiet) {
			# sometimes, the default is an array ref
			if ($DEFAULTS->{$variable}[1] == TYPE_ARRAY) {
				$value = join(', ', @{ $CONF->{$variable} });
			}
			# we want to pretty up booleans
			elsif ($DEFAULTS->{$variable}[1] == TYPE_BOOL) {
				$value = $CONF->{$variable} ? 'on' : 'off';
			}
			else {
				$value = $CONF->{$variable};
			}
			prnt $variable.' set to: '.$value;
		}
		
		# save that sucker!
		save_conf();

		# more with the quiet_manage and gui_manage
		if ( ($variable eq 'quiet_manage' || $variable eq 'gui_manage') && $CONF->{$variable} != $oldvalue) {
			del_menu();
			add_menu();
		}
	}
	elsif (!$quiet) {
		prnt 'No such variable.';
	}
	return EAT_XCHAT;
}

sub msg_highlight {
	my @msgdata = @{$_[0]};
	my $event = $_[1];

	# leave now if the nick is to be ignored
	# strip codes on nick, due to colored nicks
	my $cmpnick = strip_code($msgdata[0]);
	foreach (@{ $CONF->{ignore_nicks} }) {
		return EAT_NONE if (nickcmp($_, $cmpnick) == 0);
	}

	my $check_context;

	# default setting is to append channel, can be changed with setting
	if ($CONF->{nick_format} ne '%nick%') {
		$msgdata[0] = format_fill($CONF->{nick_format}, [$msgdata[0], $msgdata[1]]);
	}
	if ($CONF->{msg_format} ne '%message%') {
		$msgdata[1] = format_fill($CONF->{msg_format}, [$msgdata[0], $msgdata[1]]);
	}

	if ($event eq 'Channel Msg Hilight') { $event = 'Channel Message'; }
	else { $event = 'Channel Action'; }

	# Three cases, first for network tab if available, second for when each network has
	# own highlight tab, third for share
	# 2nd and 3rd case just finds the context, if it fails, creates a tab and the re-finds
	# the context to the newly created tab
	# 1st case won't ever create a context, just has to do work to find the server tab
	if ( $CONF->{shared_tab} == 2 && get_prefs('tab_server') ) {
		# start out with the base case of if things are smooth, which they may not be
		$check_context = find_context(get_info('network'), get_info('server'));
		# the strange case of if the found context is actually a query or something
		undef $check_context if ($check_context && context_info($check_context)->{type} != 1);
		if ( !$check_context ) {
			my @channels = get_list('channels');
			my $serverid = get_info('id');
			for (@channels) {
				if ($_->{id} == $serverid && $_->{type} == 1) {
					$check_context = $_->{context};
					last;
				}
			}
			# if it loops through the whole thing, we get to the end, and still no context
			# (like when tab_server was off on connect, and later turned on), need to go to
			# the next statement, don't like having parent as a seperate if block, so...
			goto HIGHLIGHT_TAB unless $check_context;
		}
	}
	# Next case if it is 0 or 2, both of which are always current server, but for 2,
	# only if it tab_server is off (silly people, if you want to save space, use shared_tab 1)
	elsif ( $CONF->{shared_tab} == 0 || $CONF->{shared_tab} == 2 ) {
		HIGHLIGHT_TAB:
		$check_context = find_context($CONF->{highlight_tab}, get_info('server'));
		if ( !$check_context ) {
			my $tab_new_to_front = get_prefs('tab_new_to_front');
			command('set -quiet tab_new_to_front 0') if ($tab_new_to_front);
			command('QUERY "'.$CONF->{highlight_tab}.'"');
			$check_context = find_context($CONF->{highlight_tab}, get_info('server'));
			command('set -quiet tab_new_to_front '.$tab_new_to_front) if ($tab_new_to_front);
		}
		
	}
	elsif ( $CONF->{shared_tab} == 1 ) {
		# need to make sure it is the shared tab rather than a possible query, which is tricky
		$check_context = find_context($CONF->{highlight_tab});
		my $problem = ($check_context && context_info($check_context)->{type} == 3);

		# if there is a problem, first have to sort through list to see if the tab exists anyway
		if ($problem) {
			my @channels = get_list('channels');
			foreach (@channels) {
				if ($_->{channel} eq $CONF->{highlight_tab} && $_->{type} != 3) {
					$check_context = $_->{context};
					$problem = 0; # no more problem!
					last;
				}
			}
		}

		# if it wasn't there, or there was another tab named that, make a new server tab
		if (!$check_context || $problem) {
			my $tab_new_to_front = get_prefs('tab_new_to_front');
			command('set -quiet tab_new_to_front 0') if ($tab_new_to_front);
			command('NEWSERVER -noconnect "'.$CONF->{highlight_tab}.'"');
			command('set -quiet tab_new_to_front '.$tab_new_to_front) if ($tab_new_to_front);
		}

		# if there still was a problem after last search, have to be careful this time around, as it still will exist
		if ($problem) {
			my @channels = get_list('channels');
			foreach (@channels) {
				if ($_->{channel} eq $CONF->{highlight_tab} && $_->{type} != 3) {
					$check_context = $_->{context};
					last;
				}
			}
		}
		# if the problem isn't there, that means no context had been found before, so set one
		# just assume it will find it, all good to go
		elsif (!$check_context) {
			$check_context = find_context($CONF->{highlight_tab});
		}
	}

	# for some reason, if context doesn't exist, don't worry about it
	if ($check_context) {
		set_context($check_context);
		prnt( format_event($event, @msgdata) );
		command('GUI COLOR '.$CONF->{color_tab}) if (0 <= $CONF->{color_tab} && $CONF->{color_tab} <= 3);
	}

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
#   usage: s/%(.)/macro_short_sub $1/eg
sub macro_short_sub ($) {
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
	$_[0] =~ s/%(.)/macro_short_sub $1/eg;
	$_[0] =~ s/\$t/\t/;
	return ($_[0]);
}

sub macro_long_sub ($$) {
	if    ($_[0] eq 'channel')          { return get_info('channel'); }
	elsif ($_[0] eq 'network')          { return network_name_priority(); }
	elsif ($_[0] eq 'network_reported') { return network_name_reported(); }
	elsif ($_[0] eq 'network_list')     { return get_info('network'); }
	elsif ($_[0] eq 'network_server')   { return get_info('server'); }
	elsif ($_[0] eq 'nick')             { return $_[1][0]; }
	elsif ($_[0] eq 'message')          { return $_[1][1]; }
	elsif ($_[0] eq 'timestamp')        { return strftime(get_prefs('stamp_text_format'), localtime); }
	return '%'.$_[0].'%';
}

sub format_fill {
	my $string = shift;
	my $data_ref = shift;
	$string =~ s/%([^%\s]+)%/macro_long_sub $1, $data_ref/eg;
	return ($string);
}

sub network_name_priority {
	my $name;
	# 2) As specified in network list, server address
	if    ($CONF->{resolve_type} == 2) {
		$name = get_info('network') || get_info('server');
	}
	# 3) As reported by server, as specified in network list, server address
	elsif ($CONF->{resolve_type} == 3) {
		$name = network_name_reported() || get_info('network') || get_info('server');
	}
	# 4) As reported by server, server address
	elsif ($CONF->{resolve_type} == 4) {
		$name = network_name_reported() || get_info('server');
	}
	# default to 1) As specified in network list, as reported by server, server address
	else {
		$name = get_info('network') || network_name_reported() || get_info('server');
	}
	return $name;
}

sub network_name_reported {
	my $reported = '';
	my @channels = get_list('channels');
	my $serverid = get_info('id');
	for (@channels) {
		if ($_->{id} == $serverid && $_->{type} == 1) {
			$reported = $_->{channel};
			last;
		}
	}
	return $reported;
}

# add new nicks to ignore highlight on to list
sub cmd_sh_ignore {
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
				message_print("Messages from $args[0] previously ignored for Show Highlight");
			}
			else {
				message_print("Messages from $args[0] now ignored for Show Higlight");
			}
		}
	}
	return EAT_XCHAT;
}

# remove nicks from ignore highlight list
sub cmd_sh_allow {
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
				message_print("Messages from $args[0] no longer ignored for Show Highlight");
			}
			else {
				message_print("Messages from $args[0] had not been ignored for Show Higlight");
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

	# need backwards compatibility due to new features
	if (defined $CONF->{append_string} && defined $CONF->{append_channel}) {
		$CONF->{nick_format} = ('%nick%' . ($CONF->{append_channel} ? $CONF->{append_string} . '%channel%' : '')) unless defined $CONF->{nick_format};
		# clean up the old vars from conf
		delete $CONF->{append_string};
		delete $CONF->{append_channel};
	}

	# set the defaults if they aren't there
	foreach (keys %$DEFAULTS) {
		$CONF->{$_} = $DEFAULTS->{$_}[0] unless defined $CONF->{$_}
	}
}

# generic message print, has a delay for after hook_prints
sub message_print {
	my $message = $_[0];
	hook_timer( 10,
		sub {
			emit_print('Generic Message', '*Show Highlight*', $message);
			return REMOVE;
		}
	);
}

# add the menu items
sub add_menu {
	if ($CONF->{gui_manage}) {
		command('timer 1 menu ADD "$NICK/Show Highlights" "sh_allow'.($CONF->{quiet_manage} ? ' -q ' : ' ').'%s"');
		command('timer 1 menu ADD "$NICK/Ignore Highlights" "sh_ignore'.($CONF->{quiet_manage} ? ' -q ' : ' ').'%s"');
	}
}

# User Menu items were added, remove them
sub del_menu {
	command('menu DEL "$NICK/Show Highlights"');
	command('menu DEL "$NICK/Ignore Highlights"');
}

load_conf();
add_menu();

__END__

Version History:
0.1  2005-09-10 Initial Code
0.2  2006-04-01 Modified Global Grouping method
1.0  2008-01-01 Cleaned up code, finally released
1.1  2008-06-04 More Cleanup
1.2  2008-07-07 No longer uses emit_print, requires 2.8.2 or higher
                  This change better handles other scripts so as to not cause
                  double emits, inadvertently send data to a non existant
                  server, or several other possible "bugs" when used with
                  with other scripts.
1.3  2009-04-13 Deal better with not stealing context
2.0  2009-09-06 Have list of users to still highlight but not show in window
                  Users can be added either with a command, or right click on
                  username in list
                Use External Configuration file
                Some Cleanup
2.1  2009-12-24 Issue when allowing a nick on clean install fixed (although,
                  The nick would have already been allowed...)
2.2  2010-02-04 Fixed case where $3 and $4 in actual message was replaced
                /sh_set to 'off' was broken, now fixed (0 worked before)
                fixed using /sh_set on ignore_nicks
                allow spaces in tab name
3.0  2010-03-23 Bug fixed where /sh_set -e wouldn't update gui config setting
                Moved version history to end of file
                /sh_set now displays booleans as 'on' and 'off'
                Changed default tab name to ':highlight:'
                Since not everyone has tab_new_to_front disabled, temp set it
                  on new tab creation (focus will never be taken)
                Make sure shared tab is a server tab, and not a lingering query
				  (thanks to Björn "Vampire" Kautler for some code)
                New nick_format and msg_format variables for fine tuning
                  appearance. nick_format replaces append_*, allowing for
                  channel and or network to be before or after nick. Channel and
                  server may also be placed in the actual message line if
                  indenting space is an issue. %network% will default to the
                  name as specified in the network list, but can use reported
                  or server canonical name
                $DEFAULTS format changed, makes things cleaner for /sh_set
3.1  2010-03-25 Bug fixes for things reported by Björn "Vampire" Kautler:
					Update in file documentation for %nick% and %message%
					Fix conversion to new format from 2.x code
					Remove redundant set_context
				Make shared_tab 2 set highlights in the server tab if available,
				  and create a query tab if not (when tab_server is 0)
				Kill a set_context that gets done by the Perl plugin anyway
3.2  2010-07-30 Now allow tab of highlight to change to something else, based
				  on the value of /sh_set color_tab (suggestion by nanotube)
3.3  2011-08-30 Allow %timestamp% in nick_format and msg_format, from /set value
				%nick% and %message% can now also be in msg_format and
				  nick_format respectively
