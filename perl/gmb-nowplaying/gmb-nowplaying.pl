#	hexchat-gmb-nowplaying.pl
#	Gets and displays information about the current song in gmusicbrowser.
#	Author: William Woodruff
#	------------------------
#	This code is licensed by William Woodruff under the MIT License.
#	http://opensource.org/licenses/MIT

use strict;
use warnings;

use Net::DBus;
use Xchat qw(:all);

my $PLUGIN_NAME = 'hexchat-gmb-nowplaying';
my $PLUGIN_VERS = '0.6';
my $PLUGIN_DESC = 'Gets information about the current song playing in gmusicbrowser.';

register($PLUGIN_NAME, $PLUGIN_VERS, $PLUGIN_DESC);

hook_command('gmb-nowplaying', \&now_playing);

sub now_playing {
	my $bus = Net::DBus->session;
	my $service = $bus->get_service('org.gmusicbrowser');
	my $object = $service->get_object('/org/gmusicbrowser', 'org.gmusicbrowser');

	my $song_info = $object->CurrentSong;

	my $title = $song_info->{title};
	my $artist = $song_info->{artist};
	my $album = $song_info->{album};
	my $year = $song_info->{year};
	my $bitrate = $song_info->{bitrate};

	command("ACTION is listening to ${title} by ${artist} (${year}, '${album}') (${bitrate}kbps)")

	return EAT_NONE;
}
