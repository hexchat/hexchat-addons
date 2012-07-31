#!/usr/bin/perl
#
# Name:		noticequery.pl
# Version:	0.1
# Author:	LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:		2005-12-26
# Description:	Sends notice messages to a query tab if a query is already open
#		for the user in question, only when tab_notices is true

# If you don't have tab_notices set, xchat behaves as normal. A (notices) tab
# will be created if none is already made.
# Special thanks to Khisanth for a few bits of code, I mean, always

Xchat::register("Notice Query", "0.1", "Redirects notices to query tabs in certain cases");
Xchat::print "Loading Notice Query 0.1";

Xchat::hook_print('Notice', \&redirect_notice, { data => { event => $event, stop => 0 }});
 
sub redirect_notice {  
	my $data = $_[1];
	return Xchat::EAT_NONE if $data->{stop};

	if (Xchat::get_prefs('tab_notices')) {
		# This bit here makes sure that each server tab keeps nicknames seperated
		my %channels = map { $_->{context}, $_ } Xchat::get_list('channels');
		my $serverid = $channels{Xchat::get_context()}{'id'};

		my @msgdata = @{$_[0]};
		my $querycontext = Xchat::find_context($msgdata[0], Xchat::get_info('server'));
		if ($channels{$querycontext}{'id'} == $serverid && Xchat::set_context($querycontext)) {
			$data->{stop} = 1;
			Xchat::emit_print('Notice', @msgdata);
			$data->{stop} = 0;
			return Xchat::EAT_XCHAT;
		}
	}
}
