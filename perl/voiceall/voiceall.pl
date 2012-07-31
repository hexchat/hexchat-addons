# Name:        voiceall-001.pl
# Version:     001
# Author:      LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:        2008-12-02
# Description: Voice everyone in a channel who isn't voice already

# Version History
# 001  2008-12-02 Initial Version

use strict;
use warnings;
use Xchat qw(:all);

register( "Voice Everyone", "001", "Voice everyone in a channel" );


hook_command( "vall", sub {
	my @tovoice = ();
	my $delay = 1;
	my $channel = get_info('channel');
	my $deal_throttle = get_prefs('net_throttle');

	my $myinfo = user_info();
	if ( $myinfo->{prefix} && $myinfo->{prefix} ne '+' ) {
		my @all_users = get_list('users');
		my $context = get_context();
		if ($deal_throttle) {
			command('set -quiet net_throttle 0');
		}
		foreach my $this_user (@all_users) {
			if ( $this_user->{prefix} ne '+') {
				push(@tovoice, $this_user->{nick});
			}
			if (scalar @tovoice == 4) {
				command('timer '. $delay++ ." mode $channel +vvvv " . join(' ', @tovoice));
				@tovoice = ();
			} 
		}
		if ( scalar @tovoice ) {
			command("timer $delay mode $channel +" . ('v' x scalar(@tovoice)) . ' ' . join(' ', @tovoice));
		}
		command('timer ' . $delay . ' set -quiet net_throttle ' . $deal_throttle);
	}
	return EAT_ALL;
});
