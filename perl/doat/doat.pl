# Name:        doat-002.pl
# Version:     002
# Author:      LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:        2009-02-21
# Description: Perform a specific command on a list of channels

# Version History
# 001  2008-12-04 Initial Version
# 002  2009-02-21 Better network handling

# Example usage:
# Creating a /mysay command which does an /allchan for specific channels only:
#   Create a User Command (Settings -> Advanced -> User Commands) with:
#     Name    = mysay
#     Command = doat #channel1,#channel2,#bridgechannel/SpecialNetwork say &2
#   Now, if you type "/mysay goodnight", this message will be sent to the first open instances
#     of #channel1 and #channel2, as well as #bridgechannel on the SpecialNetwork
# Change username on network FreeNode from some other network:
#   /doat /FreeNode nick ANewNick

Xchat::register('Do At', '002', 'Perform an arbitrary command on multiple channels');

Xchat::hook_command('doat', sub {
	if ($_[1][2]) {
		for(split(/,/, $_[0][1])) {
			my ($chan,$server) = split(/\//, $_);
			Xchat::command($_[1][2]) if (Xchat::set_context($chan,$server));
		}
	}
	return Xchat::EAT_ALL;
}, { help_text => 'DOAT [channel,list,/network] [command], perform a command on multiple contexts' });
