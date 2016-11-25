# To the extent possible under law, the author has waived all
# copyright and related or neighboring rights to this plugin.
# Paul Wise http://bonedaddy.net/pabs3/
# http://creativecommons.org/publicdomain/zero/1.0/

import hexchat

__module_name__ = 'hug'
__module_version__ = '0.1'
__module_description__ = 'Add a /hug command'

def hug_cb(word, word_eol, userdata):
	hexchat.command( "ME hugs %s" % word_eol[1] )
	return hexchat.EAT_ALL

hexchat.hook_command("hug", hug_cb, help="/HUG <nick> Sends a hug action")
