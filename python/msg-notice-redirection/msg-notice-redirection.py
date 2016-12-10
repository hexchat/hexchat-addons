# To the extent possible under law, the author has waived all
# copyright and related or neighboring rights to this plugin.
# Paul Wise http://bonedaddy.net/pabs3/
# http://creativecommons.org/publicdomain/zero/1.0/

import hexchat

__module_name__ = 'msg-notice-redirection'
__module_version__ = '0.1'
__module_description__ = 'redirect chanserv notices to the channel and messages, other notices to a query'

last_context_name = None

def recv_notice_cb(word, word_eol, userdata):
	global last_context_name
	context_name = None
	nick = word[0][1:].split('!')[0]
	to = word[2]
	if to.startswith('#'):
		return hexchat.EAT_NONE
	if nick == 'ChanServ':
		if word[3].startswith(':[#') and word[3].endswith(']'):
			context_name = word[3][2:-1]
		elif word[3].startswith(':+[#') and word[3].endswith(']'):
			context_name = word[3][3:-1]
		elif word_eol[3].startswith(':Deopped you on channel ') and word_eol[3].endswith(' because it is registered with channel services'):
			context_name = hexchat.strip(word[7])
		elif word_eol[3] == ':and you are not a CHANOP on its access list.':
			context_name = last_context_name
	if not context_name:
		context_name = nick
	if context_name:
		context = hexchat.find_context(server=hexchat.get_info('server'), channel=context_name)
		if not context:
			if context_name.startswith('#'):
				return hexchat.EAT_NONE
			else:
				hexchat.command('QUERY -nofocus %s' % context_name)
			context = hexchat.find_context(server=hexchat.get_info('server'), channel=context_name)
		if context:
			context.set()
			last_context_name = context_name
		else:
			last_context_name = None

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
