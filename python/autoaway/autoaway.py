# To the extent possible under law, the author has waived all
# copyright and related or neighboring rights to this plugin.
# Paul Wise http://bonedaddy.net/pabs3/
# http://creativecommons.org/publicdomain/zero/1.0/

import hexchat

__module_name__ = 'autoaway'
__module_version__ = '0.1'
__module_description__ = 'auto-away when you use away-indicating words'

try: away_triggers = hexchat.get_pluginpref('away_triggers').split(',')
except: away_triggers = ['bbl', 'afk', 'brb', 'bbs', 'bbiab', 'bbiaw']
hexchat.set_pluginpref('away_triggers', ','.join(away_triggers))

try: strip_words = hexchat.get_pluginpref('strip_words').split(',')
except: strip_words = ['well']
hexchat.set_pluginpref('strip_words', ','.join(strip_words))

def bbl_cb(word, word_eol, userdata):
	if len(word) >= 1 and (word[0].lower().strip(',-_') in away_triggers or word[-1].lower().strip(',-_') in away_triggers):
		if word[0].strip(',-_') in strip_words:
			away = word_eol[1]
		else:
			away = word_eol[0]
		hexchat.command( "AWAY %s" % away )

hexchat.hook_command("", bbl_cb)
