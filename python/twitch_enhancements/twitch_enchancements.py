#WIP, Uploaded for reference, please don't use.

import json
import threading
import sys

from datetime import datetime, timedelta, date, time

THREADS_SUPPORTED = True
if sys.version_info[0] == 2:
	import urllib
	if sys.platform == 'win32':
		THREADS_SUPPORTED = False
else:
	import urllib.request as urllib

import hexchat

__module_name__ = "Twitch enchancements"
__module_version__ = "0.2"
__module_description__ = "Prints jtv messages (timeouts n' stuff)"

liveChannels = []
firstRun = 1

def checkmessage_cb(word, word_eol, userdata):
	string = ' '.join(word[0:3])
	string = string.replace(string[0:1],'')
	
	if(string == 'jtv!jtv@jtv.tmi.twitch.tv PRIVMSG ' + hexchat.get_info('nick')):
		format(word_eol[3], special=1)
		return hexchat.EAT_ALL
	
	return hexchat.EAT_NONE

def stream_cb(word, word_eol, userdata):
	if THREADS_SUPPORTED:
		threading.Thread(target = stream).start()
	else:
		stream()

def stream():
	CHANNEL = hexchat.get_info("channel")

	if (hexchat.get_info("host") != "irc.twitch.tv"):
		print("/STREAM works only in irc.twitch.tv chats")
		return hexchat.EAT_ALL
	
	obj = loadJSON('https://api.twitch.tv/kraken/streams/' + CHANNEL.strip('#'))
	
	if (obj["stream"] == None):
		format(CHANNEL.title() + " is not live on twitch.tv.", special=1)
	else:
		format(CHANNEL.title() + " is streaming for " + str(obj["stream"]["viewers"]) + " viewers on " + obj["stream"]["channel"]["url"], special=1)
	
	return hexchat.EAT_ALL

def checkStreams_cb(userdata):
	if THREADS_SUPPORTED:
		threading.Thread(target = checkStreams).start()
	else:
		checkStreams()

def checkStreams():
	global firstRun
	if(firstRun):
		hexchat.unhook(timerHook)
		hexchat.hook_timer(300000, checkStreams_cb)
		firstRun = 0

	channels = hexchat.get_list("channels")
	realChannels = []
	for channel in channels:
		if(channel.server == "tmi.twitch.tv" and channel.channel[0] == '#'):
			realChannels.append(channel.channel.strip('#'))
	
	for channel in realChannels:
		obj = loadJSON('https://api.twitch.tv/kraken/streams/' + channel)
		if (obj["stream"] == None and channel in liveChannels):
			liveChannels.remove(channel)
			format(channel.title() + " is not live anymore.")
		elif (obj["stream"] != None and channel not in liveChannels):
			liveChannels.append(channel)
			format(channel.title() + " is live!")

	return 1

def uptime_cb(word, word_eol, userdata):
	if THREADS_SUPPORTED:
		threading.Thread(target = uptime).start()
	else:
		uptime()

def uptime():
	user = hexchat.get_info("channel").strip('#')
	url = 'https://api.twitch.tv/kraken/channels/' + user + '/videos?limit=1&broadcasts=true'
	
	latestbroadcast = json.loads(urllib.urlopen(url).readall().decode('utf-8'))['videos'][0]['_id']
	secondurl = 'https://api.twitch.tv/kraken/videos/' + latestbroadcast
	starttimestring = json.loads(urllib.urlopen(secondurl).readall().decode('utf-8'))['recorded_at']

	timeFormat = "%Y-%m-%dT%H:%M:%SZ"
	startdate = datetime.strptime(starttimestring, timeFormat)
	currentdate = datetime.utcnow()
	combineddate = currentdate - startdate - timedelta(microseconds=currentdate.microsecond)

	format(user.title() + " has been streaming for " + str(combineddate))

def unload_cb(userdata):
	print("\00304", __module_name__, __module_version__, "successfully unloaded.\003")

def format(string, special=0):
	if(special):
		string = string.replace(string[:1],'')
	string = '\002\035' + string
	print(string)

def loadJSON(url):
	try:
		with urllib.urlopen(url) as data:
			obj = json.loads(data.readall().decode('utf-8'))
			return obj
	except Exception:
		return json.dumps()

hexchat.hook_server('PRIVMSG', checkmessage_cb)
hexchat.hook_command('STREAM', stream_cb, help ="/STREAM Use in twitch.tv chats to check if the stream is online.")
hexchat.hook_command('UPTIME', uptime_cb)

hexchat.hook_unload(unload_cb)

timerHook = hexchat.hook_timer(10000, checkStreams_cb)


print("\00304", __module_name__, __module_version__, "successfully loaded.\003")