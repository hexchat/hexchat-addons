#!/usr/bin/env python

from __future__ import print_function
import re
import urllib2
import xchat

__module_name__ = "DownForAll"
__module_version__ = "0.2"
__module_description__ = "Parses downforeveryoneorjustme.com for you [/isdown]"

print("\0034", __module_name__, __module_version__, "(/isdown) loading...\003")

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
				xchat.command("say {} is up for me.".format(word[1]))
		except:
			xchat.command("say {} is down for me.".format(word[1]))

xchat.hook_command("isdown", isdown, help="ISDOWN <site> Says to a channel if a site is down")

