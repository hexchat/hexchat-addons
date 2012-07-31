# Name:        channoticetab-004.pl
# Version:     004
# Author:      LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:        2010-04-21
# Description: Creates a tab for all channel notices with auto reply to notice destination
#		Notices will be split up into status notices as well, so receiving a
#		/notice @#channel will be in a different tab from /notice #channel and /notice +#channel
#		(op notice, all users, and voice and higher respectively). Typing a reply in the query
#		box will result in sending a reply notice to the same users.

# Version History
# 0.1  2008-03-27 Initial Version
# 0.2  2009-02-06 Fix emit
# 003  2009-08-09 Add basic nick highlight, change versioning scheme
#        don't create extra event
# 004  2010-04-21 Fix description, fix case of $3 and $4 being replaced in notices

use strict;
use warnings;
use Xchat qw( :all );

my $NAME    = 'Chan Notice Tab';
my $VERSION = '004';

register($NAME, $VERSION, 'Creates a tab for all channel notices with auto reply to notice destination');
Xchat::print("Loading $NAME $VERSION");

hook_command('', \&catchall);

hook_print('Channel Notice', \&cnotice);

sub catchall {
	if ( get_info('channel') =~ /^:(.*)/ ) {
		command('notice ' . $1 . ' ' . $_[1][0]);
		return EAT_ALL;
	}
}

sub cnotice {
	my $tabname = ':' . $_[0][1];

	unless ( set_context($tabname, get_info('server')) ) {
		command("QUERY $tabname");
		set_context($tabname, get_info('server'));
	}

	# new version that uses extra subs to make sure not to start off other scripts
	prnt( format_event('Notice', $_[0][0], $_[0][2] ));

	# what happens if the line would highlight? well, lets change the tab color
	my $nick = quotemeta get_info('nick');
	if ($_[0][2] =~ /$nick/i) {
		# qq sometimes will strip ""s from the line, but I'm fine with that for now
		my $msg_escape = strip_code($_[0][2]);
		$msg_escape = qq($msg_escape);

		my $msg_from = 'Highlight Notice from ' .$_[0][0]. '('. $_[0][1] . ')';
		command ('gui color 3');
		command ('gui flash') if (get_prefs('input_flash_hilight'));
		command ('tray -i 5') if (get_prefs('input_tray_hilight'));
		command ('tray -t "'.$msg_from.' '.$msg_escape.'"') if (get_prefs('input_tray_hilight'));
		command ('tray -b "'.$msg_from.'" "'.$msg_escape.'"') if (get_prefs('input_balloon_hilight'));
		emit_print('Beep') if (get_prefs('input_beep_hilight'));
	}

	return EAT_NONE;
}

# Convert Text Events with data into just a string which is returned
#   usage: format_event("Channel Message", @arrayofargs)
sub format_event {
	# Expect up to 5 events (that is what text.c goes up to)
	my ($event, @items) = @_;
	$#items = 4; # force there to be 4 items

	# Future regex has problems if a string doesn't exist
	foreach (@items) {
		$_ = '' unless $_;
	}

	my $string = get_info('event_text ' . $event);

	# Do the static macro replacements
	$string = macro_fill($string);

	# Actually replace the $s
	$string =~ s/\$([1-4])/$items[$1-1]/eg;

	return $string;
}

# sub for macro replacement using ///e regex
#   usage: s/%(.)/macro_sub $1/eg
sub macro_sub ($) {
	if    ($_[0] eq 'U') { return "\c_"; }
	elsif ($_[0] eq 'B') { return "\cB"; }
	elsif ($_[0] eq 'C') { return "\cC"; }
	elsif ($_[0] eq 'O') { return "\cO"; }
	elsif ($_[0] eq 'R') { return "\cV"; }
	elsif ($_[0] eq 'H') { return "\cH"; }
	elsif ($_[0] eq '%') { return '%';   }
	return '%'.$_[0];
}

sub macro_fill {
	$_[0] =~ s/%(.)/macro_sub $1/eg;
	$_[0] =~ s/\$t/\t/;
	return ($_[0]);
}
