#!/usr/bin/env python
#create a function to both print and say to current channel....
__module_name__ = "ICycle"
__module_version__ = "0.1"
__module_description__ = "Cycles an invite-only channel"

import re
import urllib2
import xchat

print "\0034",__module_name__, __module_version__,"(/icycle)";
def icycle(word, word_eol, userdata):
	channel = xchat.get_info("channel")
	xchat.command("PART " + channel)
	xchat.command("PRIVMSG chanserv invite " + channel)
	xchat.command("JOIN" + channel)

xchat.hook_command("icycle", icycle, help="Icycle - like cylce")
