# Name:        ignore_chan_voices.pl
# Version:     002
# Author:      LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:        2010-04-29
# Description: Ignore voices that are given and removed in specified channels.

# Version History
# 001  2010-02-10 Initial Version for someone in #xchat
# 002  2010-04-29 Also ignore raw modes if only item

use strict;
use warnings;
use Xchat qw (:all);

register('Ignore Chan Voices', '002', 'Ignore voice and devoice on specified channels');

for ('Channel Voice', 'Channel DeVoice') {
	hook_print($_, \&ignore_voice);
}
hook_print('Raw Modes', \&ignore_raw_voice);

# specified the channels you wish to ignore in here, same format, lower case channels
my %ignore_list = (
	'#channel1' => 1,
	'#channel2' => 1,
);

sub ignore_voice {
	my $chan = lc get_info('channel');
	return EAT_XCHAT if (defined $ignore_list{$chan});
	return EAT_NONE;
}

sub ignore_raw_voice {
	my $chan = get_info('channel');
	return EAT_XCHAT if (defined $ignore_list{lc $chan} && $_[0][1] =~ m/^$chan [-+]v /i);
	return EAT_NONE;
}
