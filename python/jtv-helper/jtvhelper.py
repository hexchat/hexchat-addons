import hexchat
import json
import urllib.request as urllib

__module_name__ = "Jtv helper"
__module_version__ = "0.2"
__module_description__ = "General twitch.tv enchancements."

NICKNAME = hexchat.get_info('nick')

def checkmessage_cb(word, word_eol, userdata):
	#pprint(word_eol[3])
	string = ' '.join(word[0:3])
	string = string.replace(string[0:1],'')
	if(string == 'jtv!jtv@jtv.tmi.twitch.tv PRIVMSG ' + NICKNAME):
		pprint(word_eol[3])


def isstreaming_cb(word, word_eol, userdata):
	CHANNEL = hexchat.get_info("channel")

	if (hexchat.get_info("host") != "irc.twitch.tv"):
		print("/ISSTREAMING works only in irc.twitch.tv chats")
		return hexchat.EAT_ALL
	with urllib.urlopen('https://api.twitch.tv/kraken/streams/' + CHANNEL.strip('#')) as data:
		obj = json.loads(data.readall().decode('utf-8'))
		if (obj["stream"] == None):
			pprint(CHANNEL.title() + " is not live on twitch.tv.")
		else:
			pprint(CHANNEL.title() + " is streaming for " + str(obj["stream"]["viewers"]) + " viewers on " + obj["stream"]["channel"]["url"])

def pprint(string):
	string = string.replace(string[:1],'')
	string = '\002\035' + string
	print(string)

def unload_cb(userdata):
	print("\00304", __module_name__, __module_version__, "successfully unloaded.\003")

hexchat.hook_server('PRIVMSG', checkmessage_cb)
hexchat.hook_command('ISSTREAMING', isstreaming_cb, help ="/ISSTREAMING Use in twitch.tv chats to check if the stream is online.")
hexchat.hook_unload(unload_cb)

print("\00304", __module_name__, __module_version__, "successfully loaded.\003")
