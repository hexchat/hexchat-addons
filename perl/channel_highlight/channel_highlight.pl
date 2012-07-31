# Name:        channel_highlight-0.3.pl
# Version:     0.3
# Author:      LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:        2010-06-26
# Description: Specify additional highlight words on a per channel basis

# Version History
# 0.1  2008-11-14 Initial Version
# 0.2  2008-11-14 Cleanup
# 0.3  2010-06-26 Highlights now more highlighty (change tab color)

use warnings;
use strict;
use Xchat qw( :all );

my $name = 'Channel Highlight';
my $version = '0.3';

register($name, $version, 'Allow for a per-channel based highlight list');
prnt("Loading $name $version");

for ('Channel Message', 'Channel Action') {
	hook_print($_, \&channel_highlight, { priority => PRI_HIGHEST, data => $_ });
}

# todo: among other things, escape extra characters like ( ) { } [ ] ' | when importing and building this list, perhaps , separate?

my %chan_highlights = (
	'#chan1' => '(!admin|@george)',
	'#chan2' => '(peppers)'
);

sub channel_highlight {
	
	if (exists $chan_highlights{lc get_info('channel')} && $_[0][1] =~ m/(?:^|\W)$chan_highlights{lc get_info('channel')}(?:$|\W)/i)
	{
		my $event = $_[1];

		if ($event eq 'Channel Message') { $event = 'Channel Msg Hilight'; }
		else { $event = 'Channel Action Hilight'; }

		command ('gui color 3');

		emit_print( $event, @{$_[0]} );
		return EAT_ALL;
	}
	return EAT_NONE;
}
