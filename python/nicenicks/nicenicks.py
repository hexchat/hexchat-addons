#################################################################
## Nice Nicks, version <whatever it says down there>
## by Chris Gahan (chris@ill-logic.com), licensed under the WTFPL version 2.
##
## What is this?
##   This is an X-Chat script written in python which colourizes all the nicks in a channel.
##   It will check if you've got nick colouring enabled in X-Chat when it starts up, but you
##   can enable/disable it with the /NICENICKS command. It's better than the built-in colouring 
##   system because that one frqeuently assigns two people in a channel the same colour when 
##   there are still MANY unused colours.
##
## Type /HELP NICENICKS for usage info.
##
## Features:
##   + Colourize nicks based on least-recently-used colour. (When a user who has no colour starts
##     talking, it picks the colour that hasn't been used in the longest time.)
##   + Assign specific colours to specific nicks. This steals colours from other users. ;)
## 
## Features to add: (+ = new cool thing, * = bugfix, - = something else)
##   + if nicks are similar length, capitalized the same, or start with same letter, assign them
##     different colours. also, if nicks are totally different lengths, capitalization, letters
##     give them the same colours.
##

__module_name__ = "nicenicks"
__module_version__ = "0.051"
__module_description__ = "Sweet-ass nick colouring."

import re
import pickle
from xchat import *

######## GLOBALIZATION ########

if get_prefs('text_color_nicks') == 1: # if user has enabled the colored nicks option in xchat...
    nicenicks_enabled = True
else:
    nicenicks_enabled = False
    
debug_enabled = False

userparser = re.compile('^:([^!]+)!([^@]+)@(.*)$')

# You can edit the following default colour table if you want the program to use fewer colours 
# (or more colours -- I left out all the ugly ones. :) The last colour in the table gets used first.
defaultcolortable = [ (11, None), (12, None), (13, None), (7, None), (8, None), (9, None), (10, None), (3, None), (4, None), (6, None), (14, None), (15, None) ]

chancolortable = {}
permacolortable = {}

datafile = "nicenicks.dat"


######## MAKING STUFF HAPPEN FUNCS ########

def fprint(s):
    "Translate and print a string that contains x-chat %-codes"
    s = s.replace("%C", "\003") # color
    s = s.replace("%B", "\002") # bold
    s = s.replace("%U", "\037") # underline
    s = s.replace("%R", "\026") # reverse
    s = s.replace("%O", "\017") # reset
    s = s.replace("$t", "\t") # $t
    prnt(s)

def dmsg(msg, desc="DEBUG"):
    "Debug message -- Print 'msg' if debugging is enabled."
    if debug_enabled:
        fprint(str(desc)+":$t"+str(msg))

def omsg(msg, desc="(Nicenicks Info)"):
    "Other message -- Print 'msg', with 'desc' in column."
    fprint("%B"+str(desc)+"%B:$t"+str(msg))

def get_color(ctable, nick):
    """Returns the color that 'nick' should get, given the colour table 'ctable' (reusing
    the least frequently used colour if the table is full)"""

    global permacolortable

    color = None
    
    # permanent colour
    if permacolortable.has_key(nick):
        pcolor = permacolortable[nick]
    else:
        pcolor = None

    # iterate backwards through ctable
    for i in range(len(ctable)-1,-1,-1):
        c, n = ctable[i]
        
        if pcolor != None and c == pcolor: # if this nick has a permacolor
            # steal the color from whoever's using it
            ctable.pop(i)
            ctable.append((c, nick))
            return c
            
        elif n == nick:
            # push nick to top of stack if it's in there
            color = c
            ctable.append(ctable.pop(i))
            break

    if color == None:
        # otherwise, add a new entry
        c, n = ctable.pop(0)
        n = nick
        ctable.append((c,n))
        color = c

    return color
    

######## XCHAT CALLBACKS ########

def color_table_command(word, word_eol, userdata):
    "Prints a color table."

    for i in range(16):
        c = str(i)
        fprint("%OColor #"+c+"$t%C"+c+"COLOR!")

    return EAT_ALL


def setcolor_command(word, word_eol, userdata):
    "Callback for SETCOLOR command, which binds a nick to a specific color"

    global permacolortable

    paramcount = len(word) - 1 # number of parameters to this command

    if paramcount < 1: # no parameters, so display all the current nick colours
        items = permacolortable.items()
        if len(items) > 0:
            # print perma-color table
            
            omsg("These are the current permanent colour mappings:", "PERMA-COLORS")
    
            for name, color in items:
                fprint("\t   %C" + str(color) + name + " = %C11" + str(color) + "%O")
            omsg("To remove a user from this list, type /setcolor -nick", "NOTE")

        else:
            omsg("No nick colour mappings assigned. Type /HELP SETCOLOR for more info.", "PERMA-COLORS")
        
        return EAT_ALL

    nick = word[1].lower() # get lowercase nick

    if nick[0] == "-": # remove the nick!
        nick = nick[1:] # get rid of that - at the beginning
        if permacolortable.has_key(nick):
            permacolortable.pop(nick)
            omsg("Removed "+nick+" from color table", "BALEETED")
        else:
            omsg(nick+" ain't in dere, bey!", "ERRN0R")
            
        return EAT_ALL

    if paramcount == 1: # just the nick was supplied
        if permacolortable.has_key(nick):
            color = permacolortable.get(nick)
            omsg("%C"+str(color)+nick+"%O is color "+str(color), "INFO")
        else:
            omsg("%C11"+nick+"%O isn't in the database", "INFO")

    elif paramcount == 2: # nick and parameter supplied

        color = int(word[2]) # get the color

        if 0 <= color <= 15:
            # give it a new color
            permacolortable[nick] = color
            omsg("New color -> %C"+str(color)+nick+"%O", "SETCOLOR")

            dmsg("Saving permacolortable...")
            try:
                f = open(datafile, "w")
                pickle.dump(permacolortable, f)
                f.close()
            except:
                None

        else:
            omsg("Not a valid colour! Please pick one between 0 and 15. See the 'Preferences...' for the list of colours.", "ERROR")

    else:
        omsg("Too many parameters, guy!","ERRNOR")

    return EAT_ALL


def nicenicks_command(word, word_eol, userdata):
    "Enabler/disabler for the entire script"

    global nicenicks_enabled

    if len(word) == 2:
        command = word[1].lower()
        if command == "on" or command == "true" or command == "1":
            nicenicks_enabled = True
        if command == "off" or command == "false" or command == "0":
            nicenicks_enabled = False

    print "+\tNicenicks enabled: ", nicenicks_enabled
    return EAT_ALL


def nicedebug_command(word, word_eol, userdata):
    "Enabler/disabler for DEBUG INFO"

    global debug_enabled

    if len(word) == 2:
        command = word[1].lower()
        if command == "on" or command == "true" or command == "1":
            debug_enabled = True
        if command == "off" or command == "false" or command == "0":
            debug_enabled = False

    print "+\tDebug enabled: ", debug_enabled
    return EAT_ALL


def nicenicks_dump_command(word, word_eol, userdata):
    "Display nick associations for all channels"
    
    fprint("DUMP:\t")
    print(chancolortable)
    return EAT_ALL


def message_callback(word, word_eol, userdata):
    "This function is called every time a new message in a channel or query window is recieved"

    global chancolortable
    global defaultcolortable

    #-- EXAMPLE RAW COMMANDS: --
    #chanmsg: [':epitaph!~epitaph@CPE00a0241892b7-CM014480119187.cpe.net.cable.rogers.com', 'PRIVMSG', '#werd', ':mah', 'script', 'is', 'doing', 'stuff.']
    #action:  [':rlz!railz@bzq-199-176.red.bezeqint.net', 'PRIVMSG', '#werd', ':\x01ACTION', 'hugs', 'elhaym', '\x01']
    #private: [':olene!oqd@girli.sh', 'PRIVMSG', 'epinoodle', ':hey']

    if nicenicks_enabled:

        dmsg(word, "RAWCOMMAND")
        dmsg("COLORTABLE length = %d" % len(chancolortable), "RAWCOMMAND")

        if word[2][0] != "#":
            dmsg("Private message -- handing event back to X-Chat", "MSG_EVENT")
            return EAT_NONE

        chan = word[2]

        if not chancolortable.has_key(chan):
            # make new color table
            dmsg("Making new color table for "+chan, "COLORTABLE");
            chancolortable[chan] = defaultcolortable[:]
        else:
            dmsg("Found COLORTABLE of length "+str(len(chancolortable[chan]))+" for channel "+chan, "COLORTABLE")

        # get COLORTABLE for this channel
        ctable = chancolortable[chan]
        dmsg("COLORTABLE for "+chan+" = " + str(ctable), "COLORTABLE")

        userinfo = userparser.match(word[0]).groups()
        if len(userinfo) == 3:
            nick = userinfo[0]
            color = get_color(ctable, nick)
            c = str(color)

            if word[3] == ':\x01ACTION':
                action = " ".join(word[4:])
                fprint("%C"+c+"*$t"+nick+" "+action)
            else:
                fprint("%C2<%O%C"+c+nick+"%C2>%O$t"+word_eol[3][1:]+"%O")

        return EAT_XCHAT # tell xchat to eat itself

    else:
        # Don't eat this event, let other plugins and xchat see it too
        return EAT_NONE



########## HOOK IT UP ###########

try:
    permacolortable = pickle.load(open(datafile))
except:
    None

hook_server("PRIVMSG", message_callback)

hook_command("NICENICKS", nicenicks_command, None, PRI_NORM, "NICENICKS INFO:\t\nThis script will colourize nicks of users automatically, using a 'least-recently-used' algorithm (to avoid two people having the same colour).\n\nFriends' nicks can be assigned a specific colour with the SETCOLOR command, a list of colors can be shown with the COLORTABLE command, and this script can be enabled/disabled with the NICENICKS command (/NICENICKS on or /NICENICKS off).\n\nAlso, for fun, try '/NICENICKS_DUMP', or '/NICEDEBUG on'")
hook_command("NICEDEBUG", nicedebug_command, None, PRI_NORM, "Usage:\t/NICEDEBUG On to enable, /NICEDEBUG Off to disable.")
hook_command("SETCOLOR", setcolor_command, None, PRI_NORM, "Usage:\t/SETCOLOR -- show colour mappings\n/SETCOLOR [nick] [color] -- permanently maps [color] to [nick] (stealing the colour from other users if necessary)\n/SETCOLOR -[nick] -- remove [nick] from colour mapping table")
hook_command("COLORTABLE", color_table_command)
hook_command("NICENICKS_DUMP", nicenicks_dump_command, None, PRI_NORM, "Usage:\t/NICENICKS_DUMP to dump all the nick colours for all active channels")

omsg("Nicenicks loaded!")
