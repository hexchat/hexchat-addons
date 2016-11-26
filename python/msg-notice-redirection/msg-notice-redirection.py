# To the extent possible under law, the author has waived all
# copyright and related or neighboring rights to this plugin.
# Paul Wise http://bonedaddy.net/pabs3/
# http://creativecommons.org/publicdomain/zero/1.0/

import hexchat

__module_name__ = 'msg-notice-redirection'
__module_version__ = '0.1'
__module_description__ = 'redirect chanserv notices to the channel and messages, other notices to a query'

def recv_notice_cb(word, word_eol, userdata):
	nick = word[0][1:].split('!')[0]
	to = word[2]
	if to.startswith('#'):
		return hexchat.EAT_NONE
	if nick == 'ChanServ' and word[3].startswith(':[#') and word[3].endswith(']'):
		channel = word[3][2:-1]
		context = hexchat.find_context(server=hexchat.get_info('server'), channel=channel)
		if context:
			context.set()
	else:
		context = hexchat.find_context(server=hexchat.get_info('server'), channel=nick)
		if not context:
			if nick.startswith('#'):
				return hexchat.EAT_NONE
			else:
				hexchat.command('QUERY -nofocus %s' % nick)
			context = hexchat.find_context(server=hexchat.get_info('server'), channel=nick)
		if context:
			context.set()

def send_notice_cb(word, word_eol, userdata):
	global send_notice_hook
	to = word[1]
	context = hexchat.find_context(server=hexchat.get_info('server'), channel=to)
	if not context:
		if to.startswith('#'):
			return hexchat.EAT_NONE
		else:
			hexchat.command('QUERY -nofocus %s' % to)
		context = hexchat.find_context(server=hexchat.get_info('server'), channel=to)
	if context:
		context.set()
		hexchat.unhook(send_notice_hook)
		context.command(word_eol[0])
		send_notice_hook = hexchat.hook_command("NOTICE", send_notice_cb)
		return hexchat.EAT_ALL

def send_msg_cb(word, word_eol, userdata):
	hexchat.command('QUERY -nofocus %s' % word_eol[1])
	return hexchat.EAT_ALL

send_msg_hook = hexchat.hook_command("MSG", send_msg_cb)
send_notice_hook = hexchat.hook_command("NOTICE", send_notice_cb)
recv_notice_hook = hexchat.hook_server("NOTICE", recv_notice_cb)
