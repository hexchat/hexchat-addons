# Name:        masskb-004.pl
# Version:     004
# Author:      LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:        2012-12-16
# Description: Kick, Kick Ban, Remove, or Remove Ban a group of users with a common message

###### NOTE ######
# There are not buttons added in this script, you can add User List buttons in the following way:
# 1. Settings -> Advanced -> Userlist buttons
# 2. Select New, change '*NEW*' to 'Kick...' and 'EDIT ME' to 'getstr "Time for you to leave" "gkick :" "Reason to kick:" %a'
# 3. Select New, change '*NEW*' to 'KB...' and 'EDIT ME' to 'getstr "Time for you to leave" "gkickb :" "Reason to kickban:" %a'
# 4. Select New, change '*NEW*' to 'Remove...' and 'EDIT ME' to 'getstr "Time for you to leave" "gremove :" "Reason to remove:" %a'
# 5. Select New, change '*NEW*' to 'Remove&Ban' and 'EDIT ME' to 'getstr "Time for you to leave" "gremoveb :" "Reason to remove & ban:" %a'

use warnings;
use strict;
use Xchat qw( :all );
use Text::ParseWords;

# Minor ammounts of configuration
my $kickreason = "Time for you to leave"; # the default kick message, can be changed after runtime
my $kickfirst = 0; # set this to 1 or 0, at 0, bans first, then kicks to avoid auto rejoins


my $NAME    = 'Mass KB';
my $VERSION = '004';

register($NAME, $VERSION, 'Provide a method of selecting a group of nicks in the nicklist and Kick Banning them');
prnt("Loading $NAME $VERSION");

hook_command('kb_reason', \&kb_reason, { help_text => 'Usage: KB_REASON <reason>, Set the reason for Mass KB Kicks' });

hook_command('gkickb',   \&deal_group, { data => { kick => 1, remove => 0, ban => 1 }, help_text => 'Usage: GKICKB [-r "<reason>"] <nick> [<nick>]+, Kick ban a space separated list of users. Reason can be at end.' });
hook_command('gkick',    \&deal_group, { data => { kick => 1, remove => 0, ban => 0 }, help_text => 'Usage: GKICK [-r "<reason>"] <nick> [<nick>]+, Kick a space separated list of users. Reason can be at end.' });
hook_command('gremoveb', \&deal_group, { data => { kick => 0, remove => 1, ban => 1 }, help_text => 'Usage: GREMOVEB [-r "<reason>"] <nick> [<nick>]+, Remove and ban a space separated list of users. Reason can be at end.' });
hook_command('gremove',  \&deal_group, { data => { kick => 0, remove => 1, ban => 0 }, help_text => 'Usage: GREMOVE [-r "<reason>"] <nick> [<nick>]+, Remove a space separated list of users. Reason can be at end.' });

# these two left in for historical reasons, don't like the command names now
hook_command('kb_group', \&deal_group, { data => { kick => 1, remove => 0, ban => 1 }, help_text => 'Usage: GKICKB [-r "<reason>"] <nick> [<nick>]+, Kick ban a space separated list of users. Reason can be at end.' });
hook_command('k_group', \&deal_group,  { data => { kick => 1, remove => 0, ban => 0 }, help_text => 'Usage: GKICK [-r "<reason>"] <nick> [<nick>]+, Kick a space separated list of users. Reason can be at end.' });

# Allow /kb_group. If no parameters given, will kickban all users that are selected in the nick list
sub deal_group {
	# Need a few arrays because of grouping for the bans
	my @toremove = ();
	my @toban = ();

	my $channel = get_info('channel');
	my $maxmodes = context_info->{maxmodes};

	my $myinfo = user_info();

	# Don't worry about anything, unless I have the power to kick
	if ( $myinfo->{prefix} && $myinfo->{prefix} ne '+' ) {
		# get the list of users in the channel
		my @all_users = get_list('users');
		my @by_words = parse_line('\s+', 0, $_[1][1]);
		my $i = 0;
		my $localreason = $kickreason;
		# look for the reason if provided, and remove it
		while ($i < @by_words) {
			# first check to see an explicit reason
			if ($by_words[$i] eq '-r') {
				splice(@by_words, $i, 1);
				if ($by_words[$i]) {
					$localreason = $by_words[$i];
					splice(@by_words, $i, 1);
				}
			}
			# if the word has a space in it, must be the reason
			elsif ($by_words[$i] =~ /\s/) {
				$localreason = $by_words[$i];
				splice(@by_words, $i, 1);
			}
			# if one of the words starts with a colon, must be a reason from then on out
			elsif ($by_words[$i] =~ /^:/) {
				$localreason = (join(' ', splice(@by_words, $i)));
				$localreason =~ s/^:\s*//;
			}
			else {
				$i++;
			}
		}

		# If a list was provided, convert the list so it can be used in a perl regular expression
		# the list then needs to be saved separately for convenience, and a variable set that it
		# should be used
		my @check_against = ();
		my $list_provided = (scalar @by_words > 0);
		if ($list_provided) {
			foreach(@by_words) {
				push(@check_against, wildcard($_)); # wildcards converts * and ? to regex wildcards
			}
		}

		# two cases, one for if banning, the other for not, as non bans don't need to be done in groups
		if ($_[2]->{ban}) {
			# go through each user in the userlist to see if they should be kbed
			for (@all_users) {
				# See if the nick should be checked based on a list, or if it is selected
				if ($list_provided) {
					if (nick_isin($_->{nick}, \@check_against)) {
						push(@toremove, $_->{nick});
						push(@toban, ban_mask($_->{host})) if $_->{host};
					}
				}
				elsif ($_->{selected}) {
					push(@toremove, $_->{nick});
					push(@toban, ban_mask($_->{host})) if $_->{host};
				}

				# when 4 nick hosts are collected, we can do a group ban
				if (scalar @toban == $maxmodes) {
					command("mode $channel +" . ('b' x $maxmodes) . ' ' . join(' ', @toban)) if (!$kickfirst); # sometimes done
					if    ($_[2]->{kick})  { command("kick $_ $localreason") for (@toremove) }
					elsif ($_[2]->{remove}){ command("quote remove $channel $_ :$localreason") for (@toremove) }
					command("mode $channel +" . ('b' x $maxmodes) . ' ' . join(' ', @toban)) if ($kickfirst); # done the other times
					@toremove = @toban = (); # empty the arrays
				} 

			}
			# kb any remaining nicks that weren't done in the groups of 4
			if ( scalar @toban ) {
				command("mode $channel +" . ('b' x scalar(@toban)) . ' ' . join(' ', @toban)) if (!$kickfirst);
				if    ($_[2]->{kick})  { command("kick $_ $localreason") for (@toremove) }
				elsif ($_[2]->{remove}){ command("quote remove $channel $_ :$localreason") for (@toremove) }
				command("mode $channel +" . ('b' x scalar(@toban)) . ' ' . join(' ', @toban)) if ($kickfirst);
			}
			# for the case if there are nicks to kick, but no masks left
			elsif ( scalar @toremove ) {
				if    ($_[2]->{kick})  { command("kick $_ $localreason") for (@toremove) }
				elsif ($_[2]->{remove}){ command("quote remove $channel $_ :$localreason") for (@toremove) }
			}
		}
		# for when bans don't need to be done
		else {
			for (@all_users) {
				if ($list_provided) {
					if (nick_isin($_->{nick}, \@check_against)) {
						if    ($_[2]->{kick})  { command("kick $_->{nick} $localreason") }
						elsif ($_[2]->{remove}){ command("quote remove $channel $_->{nick} :$localreason") }
					}
				}
				elsif ($_->{selected}) {
					if    ($_[2]->{kick})  { command("kick $_->{nick} $localreason") }
					elsif ($_[2]->{remove}){ command("quote remove $channel $_->{nick} :$localreason") }
				}
			}
		}

	}
	return EAT_XCHAT;
}

# Set the default reason to mass kick here. If param not provided, print current string
sub kb_reason {
	if ($_[1][1]) {
		$kickreason = $_[1][1];
	}
	else {
		prnt("Current kick reason: $kickreason\n")
	}
	return EAT_XCHAT;
}

# Check to see if a nick matches a nick in a array reference of patterns
sub nick_isin {
	my $found = 0;
	foreach (@{$_[1]}) {
		if ($_[0] =~ /^$_$/i) {
			$found = 1;
			last;
		}
	}
	return $found;
}

# Taken from theromdynambot for purpose of modifying pattern matches with wildcards
sub wildcard         ($) {
	# quote meta characters coming in
	my $w = "\Q$_[0]\E"; # makes <*> -> <\*>

	# need to find and replace quotmeta'd '\\'.'\*' now, not just '\*'
	$w =~ s!\\\?     !\E(.)\Q!gx;   # one character
	$w =~ s!\\\*(?=.)!\E(.*?)\Q!gx; # non-greedy required here
	$w =~ s!\\\*    $!\E(.*)\Q!gx;  # greedy required here
	# bug fix: using .+ to find chars after '*' was skipping later wildcards,
	# should've used a look-ahead to begin with

	return $w;
}

# stealing much of this from one of b0at's scripts, why not?
sub ban_mask {
	my ($user, $host) = split(/@/,$_[0]);
	my $bantype = get_prefs('irc_ban_type');
	my $mask;

	$user =~ s/~/\*/;

	   if( $bantype == 0 ) { $mask = "*!*\@*"    .($host=~/((?:\.\w+)+)$/)[0]; }
	elsif( $bantype == 1 ) { $mask = "*!*\@$host";                             }
	elsif( $bantype == 2 ) { $mask = "*!$user\@*".($host=~/((?:\.\w+)+)$/)[0]; }
	elsif( $bantype == 3 ) { $mask = "*!$user\@$host";                         }
	else { # don't think this should happen
		prnt("Unknown irc_ban_type '$bantype', reverting to type 1 (*!*\@host).");
		$mask = "*!*\@$host"
	}
	return $mask;
}
__END__

Version History
0.1  2008-12-13 Initial Version
0.2  2008-12-13 Some efficency changes, allow for irc_ban_type, provide $kickfirst option
0.3  2008-12-13 Version Change happy. Allow for wild card matches, a bit less accurate
                  in nick comparison because of this due to case matching, but oh well
004  2011-12-16 Print current reason for kick
                Add in Remove option
                Allow for the reason in the command itself
                New primary commands for kick and kickban

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

