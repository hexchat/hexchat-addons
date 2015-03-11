#	hexchat-rainbow.pl
#	Rainbow-ifies your text.
#	Author: William Woodruff
#	------------------------
#	This code is licensed by William Woodruff under the MIT License.
#	http://opensource.org/licenses/MIT

use strict;
use warnings;

use Xchat qw(:all);

my $PLUGIN_NAME = 'rainbow';
my $PLUGIN_VERS = '1.0';
my $PLUGIN_DESC = 'rainbow-ifies your text';

register($PLUGIN_NAME, $PLUGIN_VERS, $PLUGIN_DESC, \&on_load);
Xchat::printf("Loading %s version %s", $PLUGIN_NAME, $PLUGIN_VERS);

sub on_unload {
	Xchat::printf("%s version %s unloaded.", $PLUGIN_NAME, $PLUGIN_VERS);
}

hook_command('rb', \&rainbowify, {help_text => "Usage: /rb <text> to rainbowify the given text."});

sub rainbowify {
	my $text = $_[1][1];

	if (defined $text) {
		$text =~ s/(.)/"\cC" . (int(rand(14))+2) . "\cB\cB$1"/eg;
		command("say $text");
	}

	return EAT_ALL;
}
