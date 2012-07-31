# -*- coding: utf-8; tab-width: 4; -*-

__module_name__='Growl'
__module_description__='Growl notification support'
__module_author__='TingPing'
__module_version__='13'

import re
from time import time

import xchat
try:
	import gntp.notifier
except:
	xchat.prnt('Growl Error: Please install https://github.com/kfdm/gntp')

xchatlogo = 'http://forum.xchat.org/styles/prosilver/imageset/site_logo.png'
lasttime = time()
lastnick = ''

# initial setup of growl and list of possible notifications
# hostname and password are for over the network notifications
growl = gntp.notifier.GrowlNotifier(
	applicationName='XChat',
	notifications=['Highlight', 'Private Message', 'Invited', 'Topic Changed',
					'User Online', 'Server Notice', 'Disconnected', 'Banned',
					'Killed', 'Kicked'],
	defaultNotifications=['Highlight', 'Private Message', 'Invited', 'Server Notice',
							'Disconnected', 'Killed', 'Kicked', 'Banned'],
	applicationIcon=xchatlogo,
	#hostname='localhost',
	#password=''
)

try:
	growl.register() 
except:
	xchat.prnt('Growl Error: Could not register with Growl')


def growlnotify(_type, title, desc='', pri=0):
	try:
		growl.notify(
			noteType=_type,
			title=title,
			description=desc,
			icon=xchatlogo,
			sticky=False,
			priority=pri
		)
	except: 
		xchat.prnt('Growl Error: Growl is not running.')
	return None


# now checks for and ignores mass hilights, performance impact not yet tested, maybe removed, optional, or only used on small channels
# disabled for now
# def masshilight(nick, message):
# 	userlist = ''

# 	for user in xchat.get_list('users'):
# 		if user.nick != word[0]:
# 			userlist += user.nick + ' '

# 	if re.search(userlist[:-1], xchat.strip(message)):
# 		return True

# 	else:
# 		return False

def spam(currenttime, currentnick):
	# Highlight and PM now have spam protection which previously could hang XChat
	global lasttime
	global lastnick

	if xchat.nickcmp(lastnick, currentnick) != 0:
		lasttime = time()
		lastnick = currentnick
		return False

	elif lasttime + 3 < currenttime: 
		lasttime = time()
		return False

	else:
		lasttime = time()
		return True

def active(chan):
	# Checks to see if chat is active to reduce annoying notifications
	try:
		chat = xchat.find_context()
		currentchat = chat.get_info("channel")
		status = xchat.get_info("win_status")
		if currentchat == chan and status == "active":
			return True
		else:
			return False
	except:
		return False


# start list of notifications
def hilight_callback(word, word_eol, userdata):
	if not spam(time(), word[0]): # and not masshilight(word[0], word[1]):
		growlnotify('Highlight',
					'Highlight by ' + word[0],
					word[1],
					1)

def pm_callback(word, word_eol, userdata):
	if not spam(time(), word[0]) and not active(word[0]):
		growlnotify('Private Message',
				'Messaged by ' + word[0],
				word[1],
				1)

def invited_callback(word, word_eol, userdata):
	growlnotify('Invited',
				'Invited to ' + word[0],
				'Invited to %s by %s on %s' % (word[0], word[1], word[2]))

def topic_callback(word, word_eol, userdata):
	growlnotify('Topic Changed',
				word[2] + '\'s topic changed',
				'%s \'s topic changed to %s by %s' % (word[2], word[1], word[0]),
				-2)

def onlinenotify_callback(word, word_eol, userdata):
	growlnotify('User Online',
				word[0] + ' is online on ' + word[2])

def servernotice_callback(word, word_eol, userdata):
	growlnotify('Server Notice',
				'Notice from ' + word[1],
				word[0])

def disconnect_callback(word, word_eol, userdata):
	growlnotify('Disconnected',
				'Disonnected from server',
				word[0],
				1)

def killed_callback(word, word_eol, userdata):
	growlnotify('Killed',
				'Killed by ' + word[0],
				word[1],
				2)

def kicked_callback(word, word_eol, userdata):
	growlnotify('Kicked',
				'You have been kicked from ' + word[2],
				'Kicked by %s for %s' % (word[1], word[3]),
				1)

def banned_callback(word, word_eol, userdata):
	# this now works on a basic level, will possibly be improved
	nick = xchat.get_info('nick')
	for user in xchat.get_list('users'):
		if xchat.nickcmp(nick, user.nick) == 0:
			userhost = user.host
	hostip = re.split('@', userhost)[1]

	if re.search(nick, word[1]) or re.search(hostip, word[1]):
		growlnotify('Banned',
		'You have been banned by ' + word[0])

# get events from xchat to call notifications
xchat.hook_print("Channel Msg Hilight", hilight_callback)
xchat.hook_print("Channel Action Hilight", hilight_callback)
xchat.hook_print("Private Message to Dialog", pm_callback)
xchat.hook_print("Private Action to Dialog", pm_callback)
xchat.hook_print("Invited", invited_callback)
xchat.hook_print("Notice", servernotice_callback)
xchat.hook_print("Notify Online", onlinenotify_callback)
xchat.hook_print("Topic Change", topic_callback)
xchat.hook_print("You Kicked", kicked_callback)
xchat.hook_print("Killed", killed_callback)
xchat.hook_print("Channel Ban", banned_callback)
# Nothing broke yet, its loaded! =)
xchat.prnt(__module_name__ + ' version ' + __module_version__ + ' loaded.')