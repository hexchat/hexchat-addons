# Name:        dccautomanage-003.pl
# Version:     003
# Author:      LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:        2009-10-31
# Description: Auto accept files from specific users and sort based on filename

# Version History
# 001  2009-02-22 Initial Version
# 002  2009-03-04 Accept files with spaces
# 003  2009-10-31 Automatic regex conversion
#			Allow automatic accept from /msg bot xdcc send
#			Allow Mass Add, Mass Delete for nicks

##
## Script does not need to be modified
##

use strict;
use warnings;
use Xchat qw( :all );
use Data::Dumper;

use constant {
	SCRIPT => 'DCC Auto Manage',
	VERSION => '003',
	CMD_NICK => 'AUTOACCEPT',
	CMD_PATH => 'AUTOMOVE',
	CMD_VARS => 'AUTOSET'
};

register(SCRIPT, VERSION, 'Auto accept files from specific users and sort based on filename');
prnt('Loading '.SCRIPT.' '.VERSION);

my %help_messages = (
	nick_short => CMD_NICK.' [-q] [-t] <add|del|clear|list> [<nick list>]',
	nick_long => 'Manage the list of nicks to auto accept DCCs from
  '.CMD_NICK.' add <nick1> [<nick2>+]     Add the provided nick(s) to the list to auto accept DCC files from
  '.CMD_NICK.' -t add <nick1> [<nick2>+]  As above, but nicks are only temporarily added for a set number of minutes (set by time_frame)
  '.CMD_NICK.' del <nick1> [<nick2>+]     Delete the provided nick(s) from the DCC file auto accept list
  '.CMD_NICK.' clear                      Clear the list of nicks to accept DCC files from
  '.CMD_NICK.' list                       List the nicks DCC files will auto accept from. * means temporarily
    Place "-q" before add, del, or clear to supress messages',
	path_short => CMD_PATH.' [-q] <set|del|clear|list> [<pattern>] [<path>]',
	path_long => 'Manage the list of paths to move DCC transfers to. Use quotes if needed.
  '.CMD_PATH.' set <pattern> <path>             Set the path to move a file to when it matches <pattern>
  '.CMD_PATH.' set "<pat space>" "<path space>" Same as above, but use quotes if pattern or path has a space
  '.CMD_PATH.' del <pattern>                    Delete the provided pattern from the move list
  '.CMD_PATH.' clear                            Clear the pattern list used for DCC file moving
  '.CMD_PATH.' list                             List the patterns and associated paths
    The pattern has smart wild card matching. * matches 0 or more chars, ? matchs any char, and _ matches
      any non alpha-numeric character. All non-alpha-numeric chars will also reverse match to _.
    Place "-q" before set, del, or clear to supress messages',
	vars_short => CMD_VARS.' [-q] <verbose|xdcc_mode|time_frame> [<value>]',
	vars_long => 'Modify variables as used by DCC Auto Manage
  '.CMD_VARS.'                      List all variables for DCC Auto Manage
  '.CMD_VARS.' <variable_pattern>   List variables and values. Use * for a wild card
  '.CMD_VARS." <variable> <value>   Set <variable> to the <value>. Prefix with -q to silence output
  Vars: time_frame - Minutes after issuing a \cB".CMD_NICK." -t add nick\cB to accept the file.
                    Set to 0 for -t to be like a normal add, as \cBxdcc_mode\cB uses -t
        verbose    - A positive number means more messages, 0 means fewer
        xdcc_mode  - If true, doing \cB/msg|ctcp user xdcc send\cB will automatically add the user to the accept list",               
);

hook_print('DCC SEND Offer', \&accept_file);
hook_print('DCC RECV Complete', \&recv_complete);
hook_command(CMD_VARS, \&manage_vars, { help_text => $help_messages{vars_long}});
hook_command(CMD_PATH, \&manage_paths, { help_text => $help_messages{path_long}});
hook_command(CMD_NICK, \&manage_nicks, { help_text => $help_messages{nick_long}});

# everybody needs a conf!
my $CONF;
# I like my conf in the xchat directory
my $conf_file = get_info('xchatdir').'/dccautomanage.conf';

# load the configuration to $CONF
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

# set a few default values
$CONF->{xdcc_mode} = 0 unless (defined $CONF->{xdcc_mode});
$CONF->{time_frame} = 60 unless (defined $CONF->{time_frame});
$CONF->{verbose} = 0 unless (defined $CONF->{verbose});

my @extra_hooked_commands = ();
my $timer_hook;
update_hooks(); # set initial state for /ctcp and /msg capture

# Doing /autoset xdcc_mode will change if /ctcp and /msg should be hooked
sub update_hooks {
	if (defined($CONF->{xdcc_mode}) && $CONF->{xdcc_mode}) {
		# don't do anything if the hooks are already there...
		unless (@extra_hooked_commands) {
			foreach ('ctcp', 'msg') {
				push (@extra_hooked_commands, hook_command($_, \&xdcc_request_watch));
			}
		}
	}
	# if they shouldn't be there, unhook all and clear array
	else {
		foreach (@extra_hooked_commands) {
			unhook($_);
		}
		@extra_hooked_commands = ();
	}

	# the timeout is a hook, right? well, it calls one
	# unhook an existing one so duration to nearest is updated
	unhook($timer_hook) if (defined $timer_hook);
	# now let the old be cleared and the new be updated
	update_timeout_check();
}

# generic message print, has a delay for after hook_prints
sub message_print {
	my $message = $_[0];
	hook_timer( 10,
		sub {
			emit_print('Generic Message', '*Auto Manage*', $message);
			return REMOVE;
		}
	);
}

# check to see if we have a "/ctcp|msg nickname xdcc send ..."
# This sub will only be hooked when auto xdcc mode is set
sub xdcc_request_watch {
	if ($_[1][2] =~ /^xdcc send/i) {
		# the add command has been made smart enough to not replace permanent accepts
		# however, check about verbose, and if time_frame !> 0, don't place -t flag
		command(CMD_NICK.($CONF->{verbose} ? '' : ' -q').($CONF->{time_frame} ? ' -t' : '').' add '.$_[0][1]);
	}
	return EAT_NONE;
}

# /autoaccept list
# /autoaccept add NickName
# /autoaccept del{ete} NickName
# /autoaccept -q rest (-q for quiet)
sub manage_nicks {
	my $i = 1;
	my ($quiet, $timed) = (0, 0);
	my ($action, $nick);
	my @nicks = ();

	# Accept some params that are optional, order won't matter
	while ($_[0][$i]) {
		if (lc $_[0][$i] eq '-q') { # meh, match -q and -quiet
			$quiet = 1;
		}
		elsif (lc $_[0][$i] eq '-t') {
			$timed = 1;
		}
		else {
			$action = lc $_[0][$i];
			# use a list of nicks rather than just the one
			@nicks = split(/,?\s+/, $_[1][$i+1]) if (defined $_[1][$i+1]);
			last;
		}
		$i++;
	}

	# a lovely flag for should stuff be written to disk
	my $modified = 0;

	if (!defined $action) {
		message_print('Usage: '.$help_messages{nick_short}) unless $quiet;
	}
	# adding a nick to the list
	elsif ($action eq 'add') {
		if (@nicks) {
			my @already = ();
			my @added = ();
			foreach (@nicks) {
				# with -t, we don't want to replace a normally set auto accept with a version that will time out
				if (exists($CONF->{nicks}{lc $_}) && !defined($CONF->{nicks}{lc $_})) {
					push (@already, $_);
				}
				elsif ($timed) {
					$CONF->{nicks}{lc $_} = time;
					push (@added, $_);
					# well... this will get called multiple times, and it will end up deleting the last one first
					update_timeout_check();

					# still going to write to disk because of LONG timeouts and restarts of XChat
					$modified++;
				}
				else {
					$CONF->{nicks}{lc $_} = undef;
					push (@added, $_);
					$modified++;
				}
			}
			# time to display the results!
			unless ($quiet) {
				if ($timed) {
					message_print('Nick'.($#added > 0 ?'s':'').' temporarily set to auto accept files: '.join(' ', @added)) if (@added);
					message_print('Nick'.($#already > 0 ?'s':'').' already in auto accept list. Not changing to temporary: '.join(' ', @already)) if (@already);
					
				}
				else {
					message_print('Nick'.($#added > 0 ?'s':'').' set to auto accept files: '.join(' ', @added)) if (@added);
					message_print('Nick'.($#already > 0 ?'s':'').' already in auto accept list: '.join(' ', @already)) if (@already);
				}
			}
		}
		else {
			message_print('Please specify a nick to add, usage: '.$_[0][0].' add <nickname>') unless $quiet;
		}
	}
	# deleting a nick from the list
	elsif ($action =~ /^del/) {
		if (@nicks) {
			# well, we shall have several! some good, some bad, oh noes!
			my @good = ();
			my @bad = ();
			foreach (@nicks) {
				# doing it this way rather than a flat delete due to use of undef already
				if (exists($CONF->{nicks}{lc $_})) {
					delete $CONF->{nicks}{lc $_};
					push (@good, $_);
					$modified++;
				}
				else {
					push (@bad, $_);
				}
			}
			unless ($quiet) {
				message_print('Nickname'.($#good > 0 ?'s':'').' deleted from auto accept list: '.join(' ', @good)) if (@good);
				message_print('Nickname'.($#bad > 0 ?'s were':' was').' not in the auto accept list: '.join(' ', @bad)) if (@bad);
			}
		}
		else {
			message_print('Please specify a nick to delete, usage: '.$_[0][0].' del <nickname> [<nickname>]+') unless $quiet;
		}
	}
	# deleting all nicks from the list
	elsif ($action eq 'clear') {
		$CONF->{nicks} = {};
		message_print("DCC Auto Accept list has been cleared.") unless $quiet;
		$modified++;
	}
	# listing available nicks
	elsif ($action eq 'list') {
		# astrisk nicks that are temporary
		message_print('Defined nicks to auto accept from: '.join(', ', map($_.(defined $CONF->{nicks}{$_} ? '*':''), sort keys %{$CONF->{nicks}})));
	}
	# error
	else {
		message_print('Usage: '.$help_messages{path_short}) unless $quiet;
	}
	
	# if something was changed, save the changes
	save_conf() if $modified;

	return EAT_XCHAT;
}

# /automove list
# /automove set NickName
# /automove del{ete} NickName
# /automove -q rest (-q for quiet)
sub manage_paths {
	use Text::ParseWords;
	# allow for quoted strings and \<space>
	my @params = &parse_line('\s+', 0, $_[1][1]);

	# shall things be added quietly?
	my $quiet = (defined $params[0] && $params[0] eq '-q');
	shift @params if $quiet;

	# keep track of if it gets modified to write the conf
	my $modified = 0;

	if (!defined $params[0]) {
		message_print('Usage: '.$help_messages{path_short}) unless $quiet;
	}
	# adding a pattern to the list
	elsif ($params[0] eq 'set') {
		if ($params[1] && $params[2]) {
			$CONF->{paths}{lc $params[1]} = $params[2];
			message_print('Path "'.$params[2].'" set for "'.$params[1].'"') unless $quiet;
			$modified++;

			# lets check to see if that path exists, and if we can write to it
			if (-e $params[2]) {
				if (! -w $params[2]) {
					emit_print("Generic Message", "*WARNING*", "Unable to write to path \cB$params[2]\cB");
				}
				elsif (! -d $params[2]) {
					emit_print("Generic Message", "*WARNING*", "Path is not a directory, files may be overwritten");
				}
			}
			# doesn't exist? see how far up it can be written
			else {
				use File::Spec;
				my @dirs = File::Spec->splitdir($params[2]);
				my $checking = 1;

				# Shift our way down until we find a directory that exists
				while (pop @dirs && $checking) {
					my $check_path = File::Spec->catdir(@dirs);
					if (-e $check_path) {
						# ok, so it exists, now what to do?
						if (!-w $check_path) {
							emit_print("Generic Message", "*WARNING*", "Unable to write to path \cB$check_path\cB. Please check the permissions.");
						}
						elsif (!-d $check_path) {
							emit_print("Generic Message", "*WARNING*", "Path \cB$check_path\cB is not a directory. File structure may not be created.");
						}
						# regardless, found the path, be done with it!
						$checking = 0;
					}
				}
			}
		}
		else {
			message_print('Please specify both a pattern and path, usage: '.$_[0][0].' set <pattern> <directory>') unless $quiet;
		}
	}
	# deleting a pattern from the list
	elsif ($params[0] =~ /^del/) {
		if ($params[1]) {
			# doing it this way rather than a flat delete due to use of undef already (from host lookup)
			if (delete $CONF->{paths}{lc $params[1]}) {
				message_print("Auto move for \cB$params[1]\cB deleted") unless $quiet;
				$modified++;
			}
			else {
				message_print("Pattern \cB$params[1]\cB did not exist in the list") unless $quiet;
			}
		}
		else {
			message_print('Please specify a pattern, usage: '.$_[0][0].' del <pattern>') unless $quiet;
		}
	}
	# deleting all patterns from the list
	elsif ($params[0] eq 'clear') {
		$CONF->{paths} = {};
		message_print("DCC Auto Move list has been cleared.") unless $quiet;
		$modified++;
	}
	# listing available patterns
	elsif ($params[0] eq 'list') {
		prnt("\cVPattern             Directory                         ");
		foreach (sort keys %{$CONF->{paths}}) {
			prntf("%1\$-19s %2\$s", $_, $CONF->{paths}{$_});
		}
		#message_print('Defined nicks to auto accept from: '.join(', ', sort keys %{$CONF->{paths}}));
	}
	# error
	else {
		message_print('Usage: '.$help_messages{path_short}) unless $quiet;
	}
	
	# if something was changed, save the changes
	save_conf() if $modified;

	return EAT_XCHAT;
}

#hook_command(CMD_VARS, \&manage_vars, { help_text => CMD_VARS.' [-q] <xdcc_mode|time_frame> [<value>], modify the xdcc accept settings'});
sub manage_vars {
	my $i = 1;
	my $quiet = 0;
	my ($variable, $value);

	while ($_[0][$i]) {
		if (lc $_[0][$i] eq '-q') {
			$quiet = 1;
		}
		else {
			$variable = lc $_[0][$i];
			$value = $_[1][$i+1] if defined $_[1][$i+1];
			last;
		}
		$i++;
	}

	my @all_vars = ('time_frame', 'verbose', 'xdcc_mode');

	# list available options if need be (as in, no extra param)
	unless (defined $value) {
		my @keys;
		unless ($variable) {
			@keys = @all_vars;
		}
		else {
			# turn that key into a simple string for matching
			$variable = '^'. $variable . '$';
			$variable =~ s/\*/.*/g;
			@keys = grep(/$variable/, @all_vars);
		}

		foreach(@keys) {
			prnt $_ . '.' x (29-length $_).': '. $CONF->{$_};
		}
		unless (scalar @keys) {
			prnt 'No such variable.';
		}
	}

	elsif (grep($variable eq $_, @all_vars)) {
		if ($value =~ /^-?\d+/) {
			$CONF->{$variable} = int $value;
		}
		# allow for true and "on" (or rather, anything that starts with "t")
		elsif ($value =~ /^(?:t|on)/i) {
			$CONF->{$variable} = 1;
		}
		# not true or on? call it false!
		else {
			$CONF->{$variable} = 0;
		}

		# let update_hooks decide if hooks should change
		update_hooks();

		unless ($quiet) {
			prnt $variable.' set to: '.$CONF->{$variable};
		}
		
		# save that sucker!
		save_conf();
	}
	elsif (!$quiet) {
		prnt 'No such variable.';
	}
	return EAT_XCHAT;
}

# When receving a file, check if the sender is in auto accept list
sub accept_file {
	my ($from, $file, $size, $ip) = @{$_[0]};
	if (exists($CONF->{nicks}{lc $from})) {
		# it seems to exist, so get that file!
		command("DCC GET $from \"$file\"");
	}

	return EAT_NONE;
}

# Move the file if need be
sub recv_complete {
	my ($file, $savedas, $from, $cps) = @{$_[0]};
	my $error;
	foreach my $k (keys %{$CONF->{paths}}) {
		# loop through till find a match on the key
		my $compare_string = pattern_expand($k);
		if ($file =~ m/$compare_string/i ) {
			# If the path doesn't
			if (!-e $CONF->{paths}{$k}) {
				use File::Path;
				my @created = mkpath($CONF->{paths}{$k});
				
				# if unable to create structure, error and don't move
				if (scalar @created == 0) {
					message_print("Unable to create directory structure for \cB$CONF->{paths}{$k}\cB. File not moved.");
					$error++;
				}
			}
			elsif (!-w $CONF->{paths}{$k}) {
				message_print("Unable to write to \cB$CONF->{paths}{$k}\cB. File not moved.");
				$error++;
			}

			# only do this if we haven't had an error
			unless ($error) {
				use File::Copy;
				message_print ("Move \cB$savedas\cB to \cB$CONF->{paths}{$k}\cB");
				move ($savedas, $CONF->{paths}{$k});
			}
			last;
		}
	}
	return EAT_NONE;
}

# this sub gets called when we need to verify the nicks that are accepted still should be
sub update_timeout_check {
	# we don't need to be in here if the time_frame is 0 or negative
	# in these cases, assume an indefinate acceptance
	return unless ($CONF->{time_frame});

	# Only continue if there is the open $timer_hook, otherwise, it is probably still
	# in play and eventually will get to it
	return if $timer_hook;
	
	my $earliest_nick;
	# set the time at which the last timeout should happen, so we can look for earlier
	my $earliest_time = time + $CONF->{time_frame} * 60 + 1;

	# find the nick that needs to be cleared first
	foreach (keys %{$CONF->{nicks}}) {
		# check straight times when the nicks were set
		if (defined $CONF->{nicks}{$_} && $CONF->{nicks}{$_} < $earliest_time) {
			$earliest_nick = $_;
			$earliest_time = $CONF->{nicks}{$_};
		}
	}
	
	# if there was an earliest nick, hook it!
	if (defined $earliest_nick) {
		# how many seconds are there until the earliest one should be CLEARED?
		my $time_til = $earliest_time - time + $CONF->{time_frame} * 60;

		# hey what? this should have already expired?
		if ($time_til <= 0) {
			# perhaps not the cleanest way, but this will force the loop to start over without goto or loop
			$timer_hook = hook_timer(0, \&auto_accept_temp_clean, $earliest_nick);
		}
		else {
			$timer_hook = hook_timer($time_til * 1000, \&auto_accept_temp_clean, $earliest_nick);
		}
	}
}

# this is called by a timer with the purpose of clearing out temporary nicks
sub auto_accept_temp_clean {
	# first, make sure the nick is expired, it may have been updated since then
	my $nick = lc $_[0];

	# Undef the hook, since this is used for locking
	$timer_hook = undef;

	# if the time_frame has been set to 0 or negative, allow existing nicks to stay
	if ($CONF->{time_frame}) {
		if (defined $nick && defined $CONF->{nicks}{$nick} && $CONF->{nicks}{$nick} + $CONF->{time_frame} * 60 <= time) {
			command(CMD_NICK.($CONF->{verbose} ? ' ' : ' -q ').'del '.$_[0]);
		}

		# set the next one!
		update_timeout_check();
	}

	# all done, if another one needs to be added, it will be set in update_timeout_check()
	return REMOVE;
}

# Save the conf. Use Data::Dumper to serialize it, as is Core Module
sub save_conf {
	open (DATA, '>'.$conf_file);
	print DATA '# '.SCRIPT.' '.VERSION." configruation file\n# This file is automatically generated and may be replaced\n\n";
	$Data::Dumper::Indent = 1;
	print DATA Data::Dumper->Dump([$CONF], [qw(CONF)]);

	close DATA;
	# removed the command for save_conf, but hey, why not EAT_XCHAT?
	return EAT_XCHAT;
}

# change the regex to what common bots rename things as (space to _, _ allows for space and random chars like [])
# also checks for wildcards. Pheraps allow an option later for auto expand or explicit regex
sub pattern_expand {
	my $lookfor = $_[0];

	return $_[0] unless defined $lookfor;

	$lookfor = quotemeta $lookfor;
	$lookfor =~ s/(\\[^\w\*\?\|])/[$1_]/g;
	$lookfor =~ s/_(?!\])/[\\W_]/g;
	$lookfor =~ s/\\\*/.*/g;
	$lookfor =~ s/\\\?/./g;

	return $lookfor;
}
