use strict;
use warnings;

Xchat::register("Channel Balloon", '002', 'Show balloon messages for specific channels');
Xchat::print("Loading Channel Balloon 002");

for my $event ('Channel Msg Hilight', 'Channel Action Hilight', 'Channel Message', 'Channel Action') {
	Xchat::hook_print($event, \&channel_balloon, { data => $event });
}

# list your channles, one at a time in the following format, all lower case
my @watchlist = (
	'#xchat',
	'#yourspecialchannel',
);

sub channel_balloon {
	# if the setting is to already alert, don't use the script's version
	return Xchat::EAT_NONE if (Xchat::get_prefs('input_balloon_chans'));
	# if balloons on highlight is enabled, leave now for Hilight!
	return Xchat::EAT_NONE if ($_[1] =~ /Hilight/ && Xchat::get_prefs('input_balloon_hilight'));

	my $channel = Xchat::get_info('channel');
	return Xchat::EAT_NONE unless (grep $_ eq lc $channel, @watchlist);

	my @msgdata = @{$_[0]};
	$#msgdata = 4; # force to have 4 items
	# Future regex has problems if a string doesn't exist
	foreach (@msgdata) {
		$_ = '' unless $_;
	}
	
	my $string = Xchat::get_info('event_text ' . $_[1]);
	$string =~ s/\%(?:U|B|C(?:\d{0,2}(,\d\d?)?)|O|R|H)//g;

	# Actually replace the $s
	$string =~ s/\$t/ /g;
	$string =~ s/\$([1-4])/$msgdata[$1-1]/eg;

	# Get rid of those pesky color codes
	$string = Xchat::strip_code($string);
	
	# quotes are problematic, for some reason, double quotes makes a single quote, odd escape
	$string =~ s/"/""/g;

	Xchat::command('tray -b "'.($_[1] =~ /Hilight/ ? 'Highlight in ' : 'In ') . $channel . '" "' . $string .'"');
	return Xchat::EAT_NONE;
}

__END__

Name:        channelballoon-002.pl
Version:     002
Author:      LifeIsPain < idontlikespam (at) orvp [dot] net >
Date:        2010-04-18
Description: Create alert balloons for specific channels if global not enabled

Version History:
0.1  2008-10-21 Initial Code
002  2010-04-18 Make it so don't double alert on highlight in one case, fix $3 replaces, better quote in line handling
