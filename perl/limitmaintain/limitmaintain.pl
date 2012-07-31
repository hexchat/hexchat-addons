# Name:		limitmaintain-001.pl
# Version:	001
# Author:	LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:		2009-05-06
# Description:	Show highlighted messages in a seperate tab

# Version History
# 001  2009-05-06 Initial Code

use strict;
use warnings; no warnings 'qw';
use Xchat qw (:all);

#################
# Configuration #
#################
my $limittime = 30; # number of seconds before each check
my $ceiling = 5;    # how much higher than current size
my $flux = 1;       # mode spam limiter, don't change limit if it currently is close enough
# the following is a list of channels, separated by spaces
my @channels = qw(#yourchannel #examplechan);

# no configuration needed below this point
register('Limit Maintain', '001', 'Maintain limit (+l) for channel');

hook_timer($limittime * 1000, \&check_limit);
hook_server('005', \&catch_chanmodes);

my %chanmodes = ();

# example recv line used in testing so as to not constantly disconnect
#command('recv :irc.networkname.example.com 005 find CHANLIMIT=#:50 CHANNELLEN=50 CHANMODES=eIb,k,l,BMNORScimnpstz FNC KNOCK AWAYLEN=160');

# need to keep track of CHANMODES on our own, as not in API
sub catch_chanmodes {
	$chanmodes{get_info('id')} = $1 if ( $_[1][0] =~ m/CHANMODES=(\S+)/ );
	return EAT_NONE;
}

# the timer function, loop through each @channels, set context if it exists, and limit stuff
sub check_limit {
	# some variables that will be used
	my $self_info;
	my $current_limit;
	my $user_count;

	# Check for each of our channels
	foreach(@channels) {
		if (set_context($_)) {
			$self_info = user_info;
			# this only works if % or higher, so not +
			if ($self_info->{prefix} && $self_info->{prefix} ne '+') {
				$current_limit = get_limit();
				$user_count = context_info->{users};
				# as long as a limit already exists, we may deal with limits (1 used as something like +i, but not)
				# however the current_limit must be outside of the $ceiling range, allowing for flux
				if ($current_limit > 1 && ($current_limit > $user_count + $ceiling + $flux || $current_limit < $user_count + $ceiling - $flux)) {
					# set the mode for the channel
					command('mode +l '.($user_count+$ceiling));
				}
			}
		}
	}
	return KEEP;
}

# Figure out what the limit is for the current context
sub get_limit {
	my @modeparts = split(/\s/, get_info('modes'));
	# consider -1 as either no limit, or no modes
	return -1 if !(scalar @modeparts && $modeparts[0] =~ /l/ && $chanmodes{get_info('id')});
	
	# lovely variables for keeping track
	my $pos = 0;
	my $i = 0;
	my $curchar;
	
	# only need to keep track of case 1 and 2 of 0,1,2,3 CHANMODES, as these have an arg
	$chanmodes{get_info('id')} =~ m/^[^,]*,([^,]*,[^,]*),/;
	my $careabout = $1;
	# can't figure it out? probably loaded script after connection
	return -1 if !$careabout;

	# loop through each character in first part of modes to see what position limit is
	while ($i < length $modeparts[0]) {
		$curchar = quotemeta substr($modeparts[0], $i++, 1);
		# looks like this one has a param associated with it
		$pos++ if ($careabout =~ /$curchar/);
		# if 'l' all done, no more incrementing of $pos
		last if ($curchar eq 'l');
	}

	# return what we make take for granted, but it lies otherwise
	return $modeparts[$pos];
}
