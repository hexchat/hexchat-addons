import hexchat

__module_name__ = 'BetterNotifications'
__module_author__ = 'sacarasc'
__module_version__ = '0.0.2'
__module_description__ = 'Make Win10 Notifications Look Better'

# This script should make Windows 10 notifications look better than they do by default.
# In this script, highlighted messages take the format:
# 
# Highlighted message from: sacarasc (#hexchat)
# <+sacarasc> I think you're cool, scriptuser!
#
# And channel actions are like this:
#
# Highlighted action from: sacarasc (#hexchat)
# * sacarasc hugs scriptuser.
#
# To use this, I believe you need Windows 10, as it won't work on previous.
# You will need HexChat 2.11.0+ too.
#
# Also, please turn off notifications in Settings -> Preferences -> Alerts
# for highlighted messages only. You can keep on the ones for private.

def action_cb(word, word_eol, userdata):
	
	nickname = word[0]
	action = word[1]
	channel = hexchat.get_info('channel')
	network = hexchat.get_info('network')
	
	if hexchat.get_context() == hexchat.find_context():
		return hexchat.EAT_NONE
	else:
		header = '"Highlighted action from: {} ({}/{})"'.format(nickname, channel, network)
		mainjunk = '* {} {}'.format(nickname, action)
		fullthing = 'tray -b {} {}'.format(header, mainjunk)
	
		hexchat.command(fullthing)
	
	return hexchat.EAT_NONE

def message_cb(word, word_eol, userdata):

	nickname = word[0]
	message = word[1]
	if len(word) > 2:
		mode = word[2]
	else:
		mode = ''
	channel = hexchat.get_info('channel')
	network = hexchat.get_info('network')
	
	if hexchat.get_context() == hexchat.find_context():
		return hexchat.EAT_NONE
	else:
		header = '"Highlighted message from: {} ({}/{]})"'.format(nickname, channel, network)
		mainjunk = '<{}{}> {}'.format(mode, nickname, message)
		fullthing = 'tray -b {} {}'.format(header, mainjunk)
	
		hexchat.command(fullthing)
	
	return hexchat.EAT_NONE
	
hexchat.hook_print('Channel Action Hilight', action_cb)
hexchat.hook_print('Channel Msg Hilight', message_cb)