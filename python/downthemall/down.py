#!/usr/bin/env python
#create a function to both print and say to current channel....
__module_name__ = "DownForAll"
__module_version__ = "0.1"
__module_description__ = "Parses downforeveryoneorjustme.com for you [/isdown]"

import re
import urllib2
import xchat

print "\0034",__module_name__, __module_version__,"(/isdown) loading...\003";
def isdown(word, word_eol, userdata):
	if len(word) < 2:
    		print("Choose a website")
	else:
		link = "http://downforeveryoneorjustme.com/" + word[1]
	
		data = urllib2.Request(link)
		opener = urllib2.build_opener()

#		data.add_header('User-Agent', 'Mozilla/5.0 () Gecko/20091221 Firefox/4.0.0 GTB6 ()')

		source = opener.open(data).read();

		up = re.findall('is up', source)

		try:
    			if up[0] == 'is up':
 					xchat.command("PRIVMSG "+xchat.get_info("channel") + word[1] + " is up for me.")
					xchat.prnt(word[1] + " is up for me!")
		except:
    			xchat.command("PRIVMSG " +xchat.get_info("channel") + word[1] + " is down for me.")
			xchat.prnt(word[1] + " is down for me !")
    		pass

xchat.hook_command("isdown", isdown, help="ISDOWN <site> Tells you if a site is down")
