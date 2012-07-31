# Name:          statuscolor-0.3.pl
# Version:       0.3
# Author:        LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:          2008-06-02
# Description:   Change the color of usernames in channel text based on channels status
#                (op, voice, etc)

# Version Histroy
# 0.1  2008-01-13 The Birth!
# 0.2  2008-03-02 Should use EAT_ALL instead of EAT_XCHAT
# 0.3  2008-06-20 Problem with extra events being printed in some cases fixed (using
#                 PRI_HIGH instead of PRI_LOW, as while LOW is more accurate as to when
#                 I want it to perform, did cause a problem with a different script)

use strict;
use warnings;
use Xchat qw( :all );

my $NAME    = 'Status Color';
my $VERSION = '0.3';

#############################################
#               CONFIGURATION               #
#############################################
# The following list of events will have the user name coloroized. Place a '#' before the
# line in order to not have that event have the color replaced
my @events = (
	'Channel Message',
	'Channel Action',
	'Channel Msg Hilight',
	'Channel Action Hilight',
	'Your Message',
	'Your Action',
);

# The following list of events determine the color of the nick. Use Preferences -> Colors
# for available color codes. The list below approximates the colors of the icons in the
# user list. The last line is commented, but is available if you wish to provide a color
# for users with no nick.
my %modes = (
	'+' => 24,
	'%' => 28,
	'@' => 19,
	'&' => 21,
	'~' => 22,
#	'' => 30, # If user has no mode
);
#############################################

register($NAME, $VERSION, "Change the color of usernames in channels based on channels status (op, voice, etc)");
Xchat::print("Loading $NAME $VERSION");

for my $event (@events) {
	hook_print($event, \&color_message, { data => $event, priority => PRI_HIGH });
}

my $exit;

sub color_message {
	$exit = 0;

	my @msgdata = @{$_[0]};
	my $event = $_[1];

	my $color = $modes{($msgdata[2] || '')};
	my $nick = $msgdata[0];

	if ($color) {
		if ($nick =~ /^\003$color/) {
			$exit = 1;
			return EAT_NONE;
		}

		$nick =~ s/\003\d{0,2}(?:,\d{1,2})?// ; # strip color from the nick
		$nick = "\003$color$nick\003";

		$msgdata[0] = $nick;

		emit_print($event, @msgdata) unless $exit;
		return EAT_ALL;
	}
	return EAT_ALL if $exit;
	return EAT_NONE;
}

__END__
