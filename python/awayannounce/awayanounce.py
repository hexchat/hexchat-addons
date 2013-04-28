import time
import hexchat

__module_name__ = 'AwayAnnounce'
__module_author__ = 'TingPing'
__module_version__ = '0'
__module_description__ = 'Announces away in specified channels.'

away_time = 0
announce_list = []
help_msg = 'announce add <channel>\n \
  					remove <channel>\n \
						list'

def load_list():
	global announce_list
	try:
		announce_list = hexchat.get_pluginpref('announce_list').split(',')
	except: pass

def save_list():
	hexchat.set_pluginpref('announce_list', ','.join(announce_list))

def away_cb(word, word_eol, userdata):
	global away_time
	away_time = time.time()
	reason = hexchat.get_info('away')
	for channel in hexchat.get_list('channels'):
		if channel.server == hexchat.get_info('server'):
			if channel.channel in announce_list:
				if reason:
					channel.context.command('me is away (%s)' %reason)
				else:
					channel.context.command('me is away')

def back_cb(word, word_eol, userdata):
	gone_time = None
	if away_time:
		gone_time = time.strftime('%H:%M:%S' , time.gmtime(time.time() - away_time))
	for channel in hexchat.get_list('channels'):
		if channel.server == hexchat.get_info('server'):
			if channel.channel in announce_list:
				if gone_time:
					channel.context.command('me is back (gone %s)' %gone_time)
				else:
					channel.context.command('me is back')

def announce_cb(word, word_eol, userdata):
	global announce_list
	if len(word) > 1:
		if word[1] == 'list':
			print(str(announce_list).strip('[]').replace('\'', ''))
		elif len(word) > 2:
			if word[1] == 'add':
				announce_list.append(word[2])
				save_list()
			elif word[1] == 'remove':
				try:
					announce_list.remove(word[2])
				except: pass
			else:
				hexchat.command('help announce')
	else:
		hexchat.command('help announce')
		
	return hexchat.EAT_ALL
		
def unload_callback(userdata):
	print(__module_name__ + ' version ' + __module_version__ + ' unloaded.')

hexchat.hook_command('announce', announce_cb, help=help_msg)
hexchat.hook_command('away', away_cb)
hexchat.hook_command('back', back_cb)
hexchat.hook_unload(unload_callback)
load_list()
print(__module_name__ + ' version ' + __module_version__ + ' loaded.')
