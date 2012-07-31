# Name:        whosave-003.pl
# Version:     003
# Author:      LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:        2010-01-18
# Description: Do a who on the channel or user and save the output to a file

# Version History
# 001  2009-03-30 Initial Version
# 002  2010-01-18 Work better on windows
# 003  2010-01-18 Handle UTF-8 output

use strict;
use warnings;
use Xchat qw(:all);
use File::Spec;

my $who_hook;
my $end_hook;
my $fh;

register('whosave', '003', 'Create a /whosave to save /who output to file');
hook_command('whosave', \&whosave, { help_text => 'save /who output to a file' });

sub whosave {
	my $channel = $_[0][1];
	return EAT_XCHAT unless $channel;
	my $file = File::Spec->catfile(get_info('xchatdir'), ($_[0][2] ? $_[0][2] : $_[0][1] . '.txt'));

	open ($fh, '>:encoding(UTF-8)', $file) or return EAT_XCHAT;
	
	$who_hook = hook_server('352', sub {
		print $fh $_[1][3] . "\n";
	});
	
	$end_hook = hook_server('315', sub {
		close $fh;
		unhook($who_hook);
		unhook($end_hook);
	});
	
	# now send the /who
	command("who $channel");
	
	return EAT_XCHAT;
}
