# Name:        ignore_user_channel.pl
# Version:     001
# Author:      LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:        2009-09-30
# Description: Ignore all messages from a specific user only when said in specific channels
#              Only ignores based on nick, not based on host mask

# Version History
# 001  2009-09-30 Initial Version

use strict;
use warnings;
use Xchat qw (:all);

register('Ignore User on Channel', '001', 'Ignore User on only certain channels ');

for ('Channel Msg Hilight', 'Channel Action Hilight', 'Channel Message', 'Channel Action') {
	hook_print($_, \&ignore_chan);
}

# provide your list of users and channels here, using the same form, all lower case
my %ignore_list = (
	'someuser' => [
		'#chan1',
		'#other',
	],
	'user2' => [
		'#aseparatechan',
	],
);

sub ignore_chan {
	my $from = lc strip_code($_[0][0]);
	my $chan = lc get_info('channel');
	return EAT_ALL if (defined $ignore_list{$from} && grep($chan eq $_ , @{ $ignore_list{$from} }));
	return EAT_NONE;
}
