# Name:        ignorechanctcp.pl
# Version:     002
# Author:      LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:        2010-01-29
# Description: Do not use internal handling of CTCP events directed at channel rather than user

# Version History
# 001  2010-01-18 Initial Version
# 002  2010-01-29 Fix an issue where I was modifying reference

use strict;
use warnings;
use Xchat qw (:all);

register('Ignore chan CTCP', '002', 'Do not use internal handling of CTCP events directed at channel rather than user');

# The following variable changes if the CTCP event should still be seen normally, 0 means shown, 1 means hide
my $hideevents = 0;

# Check for CTCP, if not self target, normally ignore, but possibly print
hook_server('PRIVMSG', sub {
	my ($ctcptype) = $_[1][3] =~ /^:\001(\S+).*\001$/;
	my $return = EAT_NONE; # meh, might as well do SESE
	# only go in if a) it was a ctcp b) it wasn't ACTION, and c) target wasn't self (so channel)
	if (defined $ctcptype && uc $ctcptype ne 'ACTION' && $_[0][2] ne get_info('nick')) {
		# only need to fake stuff on output if $hideevents is false
		unless ($hideevents || ignored(substr ($_[0][0], 1) , 8) ) {
			# going to assume that target has an open tab in current server id
			set_context($_[0][2]);
			# get the nick from the event
			my ($theirnick) = $_[0][0] =~ /^:([^!]+)/;
			emit_print('CTCP Generic to Channel', $ctcptype, $theirnick, $_[0][2]);
		}
		$return = EAT_XCHAT;
	}
	return $return;
});

# effectively stollen from b0at's user_match
# convert wildcard pattern to regex for matching
sub wildcard {
	my @patterns = @_;
		
	for (@patterns) {
		$_ = rfc1459lower($_);
		# special characters allowed in nicks
		s/([\$\%\@\\\][(){}|^"`'.])/\\$1/g;

		s/\?/./g; # one character

		# should the '*' wildcard be 
		#s/\*/.*/g; # greedy?
		s/\*/.*?/g; # or non-greedy?
	}

	return( wantarray? @patterns : $patterns[0] );
}

# ignored(nick!id@host.pattern, type)
# yes, this won't quite fit {} being uc of [] and similar, but perhaps later?
sub ignored {
	# only need to deal with ignores with specific type flag
	my @ignores = grep ($_->{flags} & $_[1], get_list 'ignore');
	my @exempts = grep ($_->{flags} & 32, @ignores) if @ignores;
	my $exempt = 0;
	my $ignored = 0;
	my $this;
	# assume all networks use rfc1459... not the case, but meh, api to this in xchat isn't available
	my $inhost = $_[0];
	rfc1459lower($inhost);

	# yes, the exempts could be removed from the ignores, but based on assumed average
	# case, it will be more efficient to leave them in, as it won't matter
	foreach (@exempts) {
		$this = wildcard($_->{mask});
		if ($inhost =~ /^$this$/i) {
			$exempt = 1;
			last;
		}
	}
	# unless there is an exempt, check to find out if one of the masks should be ignored that matches
	unless ($exempt) {
		foreach (@ignores) {
			$this = wildcard($_->{mask});
			if ($inhost =~ /^$this$/i) {
				$ignored = 1;
				last;
			}
		}
	}
	return $ignored;
}

# convert {}| to []\
sub rfc1459lower {
	$_[0] =~ tr/{}|/[]\\/;
	return $_[0];
}
