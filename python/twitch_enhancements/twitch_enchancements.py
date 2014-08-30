import hexchat
import json
import urllib.request as urllib
from datetime import datetime, timedelta, date, time

__module_name__ = "Twitch enchancements"
__module_version__ = "0.2"
__module_description__ = "Prints jtv messages (timeouts n' stuff)"

NICKNAME = hexchat.get_info('nick')
liveChannels = []
firstRun = 1

def checkmessage_cb(word, word_eol, userdata):
	string = ' '.join(word[0:3])
	string = string.replace(string[0:1],'')
	
	if(string == 'jtv!jtv@jtv.tmi.twitch.tv PRIVMSG ' + NICKNAME.lower()):
		format(word_eol[3], special=1)
		return hexchat.EAT_ALL
	
	return hexchat.EAT_NONE

def stream_cb(word, word_eol, userdata):
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
	if(firstRun):

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
		if (obj["stream"] != None and channel not in liveChannels):
			liveChannels.append(channel)
			format(channel.title() + " is live!")

	return 1
#hehehe
def uptime_cb(word, word_eol, userdata):
	user = hexchat.get_info("channel").strip('#')
	url = 'https://api.twitch.tv/kraken/channels/' + user + '/videos?limit=1&broadcasts=true'
	latestbroadcast = json.loads(urllib.urlopen(url).readall().decode('utf-8'))['videos'][0]['_id']
	secondurl = 'https://api.twitch.tv/kraken/videos/' + latestbroadcast
	starttimestring = json.loads(urllib.urlopen(secondurl).readall().decode('utf-8'))['recorded_at']
	print(starttimestring)
	format = "%Y-%m-%dT%H:%M:%SZ"
	startdate = datetime.strptime(starttimestring, format)
	currentdate = datetime.utcnow()
	combineddate = currentdate - startdate - timedelta(microseconds=currentdate.microsecond)
	#uptimestr = combineddate.strftime("%H:%M:%S")
	print(user + " has been streaming for " + str(combineddate))

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
hexchat.hook_unload(unload_cb)
hexchat.hook_timer(10000, checkStreams_cb)

hexchat.hook_command('UPTIME', uptime_cb)

print("\00304", __module_name__, __module_version__, "successfully loaded.\003")