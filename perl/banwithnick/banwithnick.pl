# comments while I'm waiting! strict, warnings, use Xchat... always good!
use strict;
use warnings;
use Xchat qw(:all);

# the name is kind of pathetic, and my comments mean nothing, but why not deal with both?
register('Ban With Nick', '001', 'Ban a user, but include the nick, in form nick!*@*.domain');

# change the 'banwnick' in the next line if you want to have it named something else, but don't make it an existing command
hook_command('banwnick', sub {
	my ($user_info, $domain);
	# ignore all if no param provided
	if (defined $_[0][1]) {
		# we all like user_info, don't we? do we have it?
		$user_info = user_info($_[0][1]);
		if ( defined $user_info && $user_info->{host}) {
			$domain = $user_info->{host};
			# only deal with the domain, forget the host, that will just be *'d anyway
			$domain =~ s/^[^@]+@//;
			# in one fell swoop, determine if it was an ip, and convert to format if it was!
			if ($domain =~ s/^(\d+\.\d+.\d+\.)\d+$/$1*/) {
				# there really isn't anything to do, since I did it in the if
			}
			# not an ip, so remove the first set of "word" chars up to the period, and * that
			else {
				$domain =~ s/^\w+/*/;
			}
			# send it on to ban, no mode needed, assume current context
			command('ban '.$_[0][1].'!*@'.$domain);
		}
		# huhm, they used the command and provided a param, but no dice on the host, so say so
		# the next 3 lines could be deleted if you don't want a warning
		else {
			prnt ("Unable to obtain host for $_[0][1]");
		}
	};
	# be a glutton! Eat! Eat! Eat!
	return EAT_ALL;
}, { help_text => 'banwnick <nickname>, ban the privided nick from channel as nick!*@*.domain' });
# all done, above line specifies for /help -l or /help banwnick, so you can rename if you want, but not required

__END__

Name:        banwithnick-001.pl
Version:     001
Author:      LifeIsPain < idontlikespam (at) orvp [dot] net >
Date:        2009-12-04
Description: Create a /banwnick <nick> command to ban nick!*@*.domain

Change Log
001 - 2009-12-04 - Initial version
--- - 2010-04-21 - adding this footer info and sharing
