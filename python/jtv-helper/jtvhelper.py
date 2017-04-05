import hexchat

__module_name__ = "Jtv helper"
__module_version__ = "0.1"
__module_description__ = "Prints jtv messages (timeouts n' stuff)"

NICKNAME = hexchat.get_info('nick')

def checkmessage(word, word_eol, userdata):
	#pprint(word_eol[3])
	string = ' '.join(word[0:3])
	string = string.replace(string[0:1],'')
	if(string == 'jtv!jtv@jtv.tmi.twitch.tv PRIVMSG ' + NICKNAME):
		pprint(word_eol[3])

def pprint(string):
	string = string.replace(string[:1],'')
	string = '\002\035' + string
	print(string)

def unload_cb(userdata):
	print("\00304", __module_name__, "successfully unloaded.\003")

hexchat.hook_server('PRIVMSG', checkmessage)
hexchat.hook_unload(unload_cb)

print("\00304", __module_name__, "successfully loaded.\003")