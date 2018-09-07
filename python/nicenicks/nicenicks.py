#################################################################
## Nice Nicks, version <whatever it says down there>
## maintained by BurritoBazooka (burritobazooka@gmail.com)
## authored by Chris Gahan (chris@ill-logic.com), licensed under the WTFPL version 2.
##
## What is this?
##   This is an X-Chat script written in python which colourizes all the nicks in a channel.
##   It will check if you've got nick colouring enabled in X-Chat when it starts up, but you
##   can enable/disable it with the /NICENICKS command. It's better than the built-in colouring
##   system because that one frequently assigns two people in a channel the same colour when
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
##
# TODO: switch from pickle to json, and use hexchat.set_pluginpref
from __future__ import print_function

__module_name__ = "nicenicks"
__module_version__ = "0.09"
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
debug_enabled = set()

# You can edit the following default colour table if you want the addon to use fewer colours
# (or more colours -- I left out all the ugly ones. :) The first colour in the table gets used first.
defaultcolortable = [ (11, None), (4, None), (13, None), (7, None), (8, None), (9, None), (10, None), (3, None), (12, None), (6, None), (14, None), (15, None) ]

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

color3_tabs = []
current_focus_tab = None

def jprint(*objects):
    hexchat.prnt("".join(objects))


def ecs(series):
    "return a series of escape codes"
    return "".join([ec[code] for code in series])


def col(foreground, background=None):
    if background is not None:
        return ec["c"] + str(foreground).zfill(2) + "," + str(background).zfill(2)
    else:
        return ec["c"] + str(foreground).zfill(2)

def dmsg(msg, desc="DEBUG", prefix="(nn) "):
    "Debug message -- Print 'msg' if debugging is enabled."
    if "*" in debug_enabled or desc in debug_enabled:
        omsg(msg, desc, prefix)

def omsg(msg, desc="Info", prefix="(nn) "):
    "Other message -- Print 'msg', with 'desc' in column."
    jprint(ecs("b"), str(prefix), str(desc), ecs("bt"), str(msg))

def get_color(ctable, nick):
    """Returns the color that 'nick' should get, given the colour table 'ctable' (reusing
    the least frequently used colour if the table is full)"""

    global permacolortable

    color = None
    nick = nick.lower()

    # permanent colour
    if nick in permacolortable:
        pcolor = permacolortable[nick]
        dmsg('In permacolortable')
    else:
        dmsg('%s not in permacolortable: %s' % (nick, permacolortable))
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

    for color in range(32):
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
        if nick in permacolortable:
            permacolortable.pop(nick)
            omsg("Removed "+nick+" from color table", "BALEETED")
        else:
            omsg(nick+" ain't in dere, bey!", "ERRN0R")

        return hexchat.EAT_ALL

    if paramcount == 1: # just the nick was supplied
        if nick in permacolortable:
            color = permacolortable.get(nick)
            omsg(col(color) + nick + ecs("o") + " is color " + str(color), "INFO")
        else:
            omsg(col(11) + nick + ecs("o") + " isn't in the database", "INFO")

    elif paramcount == 2: # nick and parameter supplied

        color = int(word[2]) # get the color

        if 0 <= color <= 31:
            # give it a new color
            permacolortable[nick] = color
            omsg("".join(["New color -> ", col(color), nick, ecs("o")]), "SETCOLOR")

            dmsg("Saving permacolortable...")

            try:
                f = open(datafile, "wb")
                pickle.dump(permacolortable, f)
                f.close()
            except BaseException as e:
                omsg("There was an error trying to save permacolortable:", "ERR_FILEWRITE")
                omsg(e, "ERR_FILEWRITE")
                omsg("The file path we were trying to write to was:", "ERR_FILEWRITE")
                omsg(os.path.abspath(datafile), "ERR_FILEWRITE")

        else:
            omsg("Not a valid colour! Please pick one between 0 and 31. See the 'Preferences...' for the list of colours.", "ERROR")

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
            debug_enabled = set("*")
        elif command == "off" or command == "false" or command == "0":
            debug_enabled = set()
        elif word[1].startswith("-"):
            debug_enabled.discard(word[1][1:])
        else:
            debug_enabled.add(word[1])

    print("+\tNicenicks Debug enabled: ", debug_enabled or "Off")
    return hexchat.EAT_ALL


def nicenicks_dump_command(word, word_eol, userdata):
    "Display nick associations for all channels"
    omsg("DUMP:\t", "Nicenicks dump", prefix="")
    if len(word) > 1 and word[1].lower() == "raw":
        print(chancolortable)
        return hexchat.EAT_ALL
    for network, channels in chancolortable.items():
        print("===", network, "===")
        for channel, nicks in channels.items():
            print("=", channel, "=")
            this_channel_table = []
            for color, nick in nicks:
                if nick is not None:
                    this_channel_table.append("".join([col(color), nick, ecs("o"), ": ", str(color)]))
            print(", ".join(this_channel_table))
    return hexchat.EAT_ALL

def tab_hilight_callback(word, word_eol, userdata, attributes):
    """Called when we expect a tab to be coloured '3', so we don't override that
    colour with the colour '2' in message_callback."""
    ctx = hexchat.get_context()
    if ctx != current_focus_tab:
        color3_tabs.append(ctx)
        dmsg("Got highlight. Added this context to color3_tabs.", "GUICOLOR")
    return hexchat.EAT_NONE

def is_color3_tab(our_ctx):
    for ctx in color3_tabs:
        if ctx == our_ctx:
            return True
    return False

def tab_focus_callback(word, word_eol, userdata):
    """Undoes the action in tab_hilight_callback so that we can colour tabs '2' again."""
    global color3_tabs
    global current_focus_tab
    our_ctx = hexchat.get_context()
    current_focus_tab = our_ctx
    dmsg("Focus changed to {}. Current color3_tabs: {!r}".format(current_focus_tab, color3_tabs), "GUICOLOR")
    
    n = len(color3_tabs)
    color3_tabs = [ctx for ctx in color3_tabs if ctx != our_ctx]
    nremoved = n - len(color3_tabs)
    if nremoved:
        dmsg("Removed {} tab{} from color3_tabs.".format(nremoved, "s"*(nremoved!=1)), "GUICOLOR")
    return hexchat.EAT_NONE

def message_callback(word, word_eol, userdata, attributes):
    """"This function is called every time a new 'Channel Message' or
    'Channel Action' (like '/me hugs elhaym') event is going to occur.
    Here, we change the event in the way we desire then pass it along."""
    global chancolortable
    global defaultcolortable
    if nicenicks_enabled:
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
        dmsg("COLORTABLE length = %d" % len(chancolortable), "PRINTEVENT")

        chan = hexchat.get_info("channel")
        net = hexchat.get_info("network")
        ctx = hexchat.get_context()
        if net not in chancolortable:
            # create an empty network entry
            dmsg("Making new network "+net, "COLORTABLE")
            chancolortable[net] = {}
            dmsg("chancolortable: %s" % (chancolortable))
        if chan not in chancolortable[net]:
            # make new color table
            dmsg("Making new color table for "+chan, "COLORTABLE")
            chancolortable[net][chan] = defaultcolortable[:]
            dmsg("chancolortable: %s" % (chancolortable))
        else:
            dmsg("Found COLORTABLE of length "+str(len(chancolortable[net][chan]))+" for channel "+chan+" on network "+net, "COLORTABLE")
        ctable = chancolortable[net][chan]
        dmsg("COLORTABLE for "+chan+" on "+net+" = " + str(ctable), "COLORTABLE")
        color = get_color(ctable, nick)
        newnick = ecs('o') + col(color) + nick
        word[0] = newnick
        dmsg('Old nick: %s - New Nick: %s' % (nick, newnick))
        hexchat.emit_print(event_name, *word, time=attributes.time)
        if not is_color3_tab(ctx):
            hexchat.command("gui color 2") # required since HexChat 2.12.4
        return hexchat.EAT_ALL
    else:
        return hexchat.EAT_NONE

def change_nick_callback(word, word_eol, userdata, attributes):
    # Considering that we have a limited amount of colours,
    # we don't need to occupy a new entry in the table if someone changes their nick.
    # We replace their old entry with the new nick.
    oldnick, newnick = word
    chan = hexchat.get_info("channel")
    net = hexchat.get_info("network")
    
    net_table = chancolortable.get(net)
    if net_table:
        ctable = net_table.get(chan)
        if ctable:
            for i, (color, nick) in enumerate(ctable):
                if nick and nick.lower() == oldnick.lower():
                    ctable[i] = (color, newnick.lower())
                    dmsg("Nick change, table updated: {0}{1}{3} -> {0}{2}{3}".format(col(color), oldnick, newnick, ec['o']), "NICKCHANGE")
                    return hexchat.EAT_NONE
    return hexchat.EAT_NONE

########## HOOK IT UP ###########

try:
    permacolortable = pickle.load(open(datafile,"rb"))
except:
    pass

hexchat.hook_print_attrs("Channel Message", message_callback, "Channel Message", priority=hexchat.PRI_HIGHEST)
hexchat.hook_print_attrs("Channel Action", message_callback, "Channel Action", priority=hexchat.PRI_HIGHEST)
hexchat.hook_print_attrs("Channel Msg Hilight", tab_hilight_callback, priority=hexchat.PRI_LOW)
hexchat.hook_print_attrs("Channel Action Hilight", tab_hilight_callback, priority=hexchat.PRI_LOW)
hexchat.hook_print("Focus Tab", tab_focus_callback, priority=hexchat.PRI_LOW)
hexchat.hook_print_attrs("Change Nick", change_nick_callback, priority=hexchat.PRI_LOW)

hexchat.hook_command("NICENICKS", nicenicks_command, None, hexchat.PRI_NORM, "NICENICKS INFO:\t\nThis script will colourize nicks of users automatically, using a 'least-recently-used' algorithm (to avoid two people having the same colour).\n\nFriends' nicks can be assigned a specific colour with the SETCOLOR command, a list of colours can be shown with the COLORTABLE command, and this script can be enabled/disabled with the NICENICKS command (/NICENICKS on or /NICENICKS off).\n\nAlso, for fun, try '/NICENICKS_DUMP', or '/NICEDEBUG on'")
hexchat.hook_command("NICEDEBUG", nicedebug_command, None, hexchat.PRI_NORM, "Usage:\t/NICEDEBUG On to enable for all messages, /NICEDEBUG Off to disable, or to enable showing only debug messages with a certain description: '/NICEDEBUG description'. Remove a description: '/NICEDEBUG -description'")
hexchat.hook_command("SETCOLOR", setcolor_command, None, hexchat.PRI_NORM, "Usage:\t/SETCOLOR -- show colour mappings\n/SETCOLOR [nick] [color] -- permanently maps [color] to [nick] (stealing the colour from other users if necessary)\n/SETCOLOR -[nick] -- remove [nick] from colour mapping table")
hexchat.hook_command("COLORTABLE", color_table_command)
hexchat.hook_command("NICENICKS_DUMP", nicenicks_dump_command, None, hexchat.PRI_NORM, "Usage:\t/NICENICKS_DUMP to dump all the nick colours for all active channels. To show the raw table without colours (might not fit on one line): /NICENICKS_DUMP raw")

omsg("Nicenicks version {} loaded!".format(__module_version__))
print("+\tNicenicks enabled:", nicenicks_enabled)
if not nicenicks_enabled:
    print("+\tTo have Nicenicks enabled on start, do '/set text_color_nicks 1', or turn that setting on at:")
    print("+\tSettings → Preferences → Appearance → Colored nick names")
defctable = 'Default colour table:'
for c, n in defaultcolortable:
    defctable = '{0} \003{1:02d}{1:02d}'.format(defctable,c)
omsg(defctable)
