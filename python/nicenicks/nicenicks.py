#################################################################
## Nice Nicks, version <whatever it says down there>
## maintained by BurritoBazooka (burritobazooka@googlemail.com)
## authored by Chris Gahan (chris@ill-logic.com), licensed under the WTFPL version 2.
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
##   + Could also do this when we see two users' nicks occurring close together very frequently
##     over time, making them easier to differentiate in a conversation.
##   + Another idea for doing nick colouring is to assign more than one colour to a nick which has
##     more than one recognisable part. For example, "JoeBloggs17" could have "Joe",
##     "Bloggs", and "17" coloured differently to each other - for more uniqueness.
##   + XChat compatibility. Currently when trying to port this script back to XChat, strange
##     behaviour was encountered where a caught event would be treated normally anyway, even
##     though our callback returned EAT_XCHAT or EAT_ALL. I don't know how to solve that.

from __future__ import print_function

__module_name__ = "nicenicks"
__module_version__ = "0.07"
__module_description__ = "Sweet-ass nick colouring."

from collections import defaultdict
import os
import pickle
import hexchat

######## GLOBALIZATION ########

if hexchat.get_prefs('text_color_nicks') == 1: # if user has enabled the
# colored nicks option in xchat...
    nicenicks_enabled = True
else:
    nicenicks_enabled = False
    
debug_enabled = False

# You can edit the following default colour table if you want the program to use fewer colours 
# (or more colours -- I left out all the ugly ones. :) The last colour in the table gets used first.
defaultcolortable = [ (11, None), (12, None), (13, None), (7, None), (8, None), (9, None), (10, None), (3, None), (4, None), (6, None), (14, None), (15, None) ]

chancolortable = {}
permacolortable = {}

datafile = os.path.join(hexchat.get_info("configdir"), "nicenicks.dat")
# Default behaviour before v0.07 was to create file in current working directory (most likely the user's home directory).

ec = defaultdict(str)

# This is used to specify control characters in the script.
ec.update({"b": "\002",  # bold
          "c": "\003",  # color
          "h": "\010",  # italics
          "u": "\037",  # underline
          "o": "\017",  # original attributes
          "r": "\026",  # reverse color
          "e": "\007",  # beep
          "i": "\035",  # italics
          "t": "\t"}  # tab
         )


######## MAKING STUFF HAPPEN FUNCS ########

def jprint(*objects):
    hexchat.prnt("".join(objects))


def ecs(series):
    "return a series of escape codes"
    return "".join([ec[code] for code in series])


def col(foreground, background=None):
    if background is not None:
        return ec["c"] + str(foreground) + "," + str(background)
    else:
        return ec["c"] + str(foreground)

def dmsg(msg, desc="DEBUG", prefix="(nn) "):
    "Debug message -- Print 'msg' if debugging is enabled."
    if debug_enabled:
        omsg(msg, desc, prefix)

def omsg(msg, desc="Info", prefix="(nn) "):
    "Other message -- Print 'msg', with 'desc' in column."
    jprint(ecs("b"), str(prefix), str(desc), ecs("bt"), str(msg))

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
        
        if pcolor != None and c == pcolor: # if we found this nick's permcolor
            # steal the color from whoever's using it
            ctable.pop(i)
            ctable.append((c, nick))
            dmsg("1: " + str(c) + " " + nick)
            return c
            
        elif n == nick:
            color = c
            if pcolor != None and c != pcolor: # if this nick has a color in the table different from its permacolor
                # change the color in the color table
                ctable.pop(i)
                dmsg(nick + "'s permacolor was found to be different from the one in the table, and was reassigned from " + str(c) + " to " + str(pcolor), "GETCOLOR")
                c = color = pcolor
                ctable.append((c, nick))
                break
            else:
                # push nick to top of stack if it's in there
                dmsg(nick + "'s color was found in the colortable for this channel.", "GETCOLOR")
                ctable.append(ctable.pop(i))
                break

    if color == None:
        # otherwise, add a new entry
        c, n = ctable.pop(0)
        n = nick
        ctable.append((c,n))
        color = c
        dmsg("A new entry was added to this colortable: " + nick + " -> " + str(c), "GETCOLOR")
    dmsg("Resultant color: " + str(color), "GETCOLOR")
    return color
    

######## XCHAT CALLBACKS ########

def color_table_command(word, word_eol, userdata):
    "Prints a color table."

    for color in range(16):
        jprint(ecs("o"), "Color #", str(color), "\t", col(color), "COLOR!")

    return hexchat.EAT_ALL

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
                jprint("\t   ", col(color), name, " = ", col(11), str(color), ecs("o"))
            omsg("To remove a user from this list, type /setcolor -nick", "NOTE")

        else:
            omsg("No nick colour mappings assigned. Type /HELP SETCOLOR for more info.", "PERMA-COLORS")
        
        return hexchat.EAT_ALL

    nick = word[1].lower() # get lowercase nick

    if nick[0] == "-": # remove the nick!
        nick = nick[1:] # get rid of that - at the beginning
        if permacolortable.has_key(nick):
            permacolortable.pop(nick)
            omsg("Removed "+nick+" from color table", "BALEETED")
        else:
            omsg(nick+" ain't in dere, bey!", "ERRN0R")

        return hexchat.EAT_ALL

    if paramcount == 1: # just the nick was supplied
        if permacolortable.has_key(nick):
            color = permacolortable.get(nick)
            omsg(col(color) + nick + ecs("o") + " is color " + str(color), "INFO")
        else:
            omsg(col(11) + nick + ecs("o") + " isn't in the database", "INFO")

    elif paramcount == 2: # nick and parameter supplied

        color = int(word[2]) # get the color

        if 0 <= color <= 15:
            # give it a new color
            permacolortable[nick] = color
            omsg("".join(["New color -> ", col(color), nick, ecs("o")]), "SETCOLOR")

            dmsg("Saving permacolortable...")

            try:
                f = open(datafile, "w")
                pickle.dump(permacolortable, f)
                f.close()
            except BaseException as e:
                omsg("There was an error trying to save permacolortable:", "ERR_FILEWRITE")
                omsg(e, "ERR_FILEWRITE")
                omsg("The file path we were trying to write to was:", "ERR_FILEWRITE")
                omsg(os.path.abspath(datafile), "ERR_FILEWRITE")

        else:
            omsg("Not a valid colour! Please pick one between 0 and 15. See the 'Preferences...' for the list of colours.", "ERROR")

    else:
        omsg("Too many parameters, guy!","ERRNOR")

    return hexchat.EAT_ALL


def nicenicks_command(word, word_eol, userdata):
    "Enabler/disabler for the entire script"

    global nicenicks_enabled

    if len(word) == 2:
        command = word[1].lower()
        if command == "on" or command == "true" or command == "1":
            nicenicks_enabled = True
        if command == "off" or command == "false" or command == "0":
            nicenicks_enabled = False

    print("+\tNicenicks enabled:", nicenicks_enabled)
    return hexchat.EAT_ALL


def nicedebug_command(word, word_eol, userdata):
    "Enabler/disabler for DEBUG INFO"

    global debug_enabled

    if len(word) == 2:
        command = word[1].lower()
        if command == "on" or command == "true" or command == "1":
            debug_enabled = True
        if command == "off" or command == "false" or command == "0":
            debug_enabled = False

    print("+\tNicenicks Debug enabled: ", debug_enabled)
    return hexchat.EAT_ALL


def nicenicks_dump_command(word, word_eol, userdata):
    "Display nick associations for all channels"
    
    omsg("DUMP:\t", "Nicenicks dump", prefix="")
    print(chancolortable)
    return hexchat.EAT_ALL


def message_callback(word, word_eol, userdata, attributes):
    """"This function is called every time a new 'Channel Message' or
    'Channel Action' (like '/me hugs elhaym') event is going to occur.
    Here, we change the event in the way we desire then pass it along."""
    global chancolortable
    global defaultcolortable
    if nicenicks_enabled:
        dmsg("COLORTABLE length = %d" % len(chancolortable), "PRINTEVENT")
        event_name = userdata
        nick = word[0]
        nick = hexchat.strip(nick, -1, 1) # remove existing colours

        # This bit prevents infinite loops.
        # Assumes nicks will never normally begin with "\017".
        if nick.startswith(ec["o"]):
            # We already did this event and are seeing it again, because this function gets triggered by events that even it generates.
            dmsg("Already-processed nick found: " + repr(nick), "LOOP")
            return hexchat.EAT_NONE

        dmsg("The time attribute for this event is {}".format(attributes.time), "PRINTEVENT")

        chan = hexchat.get_info("channel")
        net = hexchat.get_info("network")
        if not chancolortable.has_key((net, chan)):
            # make new color table
            dmsg("Making new color table for "+chan, "COLORTABLE")
            chancolortable[net, chan] = defaultcolortable[:]
        else:
            dmsg("Found COLORTABLE of length "+str(len(chancolortable[net, chan]))+" for channel "+chan+" on network "+net, "COLORTABLE")
        ctable = chancolortable[net, chan]
        dmsg("COLORTABLE for "+chan+" on "+net+" = " + str(ctable), "COLORTABLE")
        color = get_color(ctable, nick)
        newnick = ecs('o') + col(color) + nick
        word[0] = newnick
        hexchat.emit_print(event_name, *word, time=attributes.time)
        return hexchat.EAT_ALL
    else:
        return hexchat.EAT_NONE


########## HOOK IT UP ###########

try:
    permacolortable = pickle.load(open(datafile))
except:
    pass

hexchat.hook_print_attrs("Channel Message", message_callback, "Channel Message", priority=hexchat.PRI_HIGHEST)
hexchat.hook_print_attrs("Channel Action", message_callback, "Channel Action", priority=hexchat.PRI_HIGHEST)

hexchat.hook_command("NICENICKS", nicenicks_command, None, hexchat.PRI_NORM, "NICENICKS INFO:\t\nThis script will colourize nicks of users automatically, using a 'least-recently-used' algorithm (to avoid two people having the same colour).\n\nFriends' nicks can be assigned a specific colour with the SETCOLOR command, a list of colors can be shown with the COLORTABLE command, and this script can be enabled/disabled with the NICENICKS command (/NICENICKS on or /NICENICKS off).\n\nAlso, for fun, try '/NICENICKS_DUMP', or '/NICEDEBUG on'")
hexchat.hook_command("NICEDEBUG", nicedebug_command, None, hexchat.PRI_NORM, "Usage:\t/NICEDEBUG On to enable, /NICEDEBUG Off to disable.")
hexchat.hook_command("SETCOLOR", setcolor_command, None, hexchat.PRI_NORM, "Usage:\t/SETCOLOR -- show colour mappings\n/SETCOLOR [nick] [color] -- permanently maps [color] to [nick] (stealing the colour from other users if necessary)\n/SETCOLOR -[nick] -- remove [nick] from colour mapping table")
hexchat.hook_command("COLORTABLE", color_table_command)
hexchat.hook_command("NICENICKS_DUMP", nicenicks_dump_command, None, hexchat.PRI_NORM, "Usage:\t/NICENICKS_DUMP to dump all the nick colours for all active channels")

omsg("Nicenicks version {} loaded!".format(__module_version__))
