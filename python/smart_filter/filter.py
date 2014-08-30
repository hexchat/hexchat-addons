__module_name__ = 'Filter'
__module_version__ = '1.0'
__module_description__ = 'Filters join/part messages'

import hexchat
from time import time

last_seen = {} # For each entry: the key is the user's nickname, the entry
               # is a list: element 0: last seen time
               #            element 1: 0 if the user never spoke, 1 otherwise
user_timeout = 600 # If the user hasn't spoken for this amount of seconds, his
                   # join/part messages won't be shown
halt = False

def human_readable(s):
    deltas = [
        ("seconds", int(s)%60),
        ("minutes", int(s/60)%60),
        ("hours", int(s/60/60)%24),
        ("days", int(s/24/60/60)%30),
        ("months", int(s/30/24/60/60)%12),
        ("years", int(s/12/30/24/60/60))
    ]
    tarr = ['%d %s' % (d[1], d[1] > 1 and d[0] or d[0][:-1])
        for d in reversed(deltas) if d[1]]
    return " ".join(tarr[:2])

def new_msg(word, word_eol, event, attrs):
    """Handles normal messages.

    Unless this is the first user's message since he joined, the message will
    not be altered. Otherwise, a '(logged in Xs ago)' message will be appended.

    """
    global halt
    if halt is True:
        return
    user = hexchat.strip(word[0])
    # If the user logged in before we did (which means the Join part of
    # filter_msg didn't take effect), add him to the dict.
    if user not in last_seen:
        last_seen[user]= [time(), 1]
    # If the user has never spoken before, let us know when he logged in.
    if last_seen[user][1] == 0:
        time_diff = time() - last_seen[user][0]
        word[1] += " \00307(logged in %s ago)" % human_readable(time_diff)
        halt = True
        hexchat.emit_print(event, *word)
        halt = False
        last_seen[user]= [time(), 1]
        return hexchat.EAT_ALL
    else:
        last_seen[user]= [time(), 1]

def filter_msg(word, word_eol, event, attrs):
    """Filters join and part messages"""
    user = hexchat.strip(word[0])
    # If the user just joined, add him to the dict and mark him as such
    #if 'Join' in userdata:
    if event == "Join":
        if user not in last_seen:
            last_seen[user] = [time(), 0]
            return hexchat.EAT_ALL
    # If the user changed his nick, check if we've been tracking him before
    # and transfer his stats if so. Otherwise, add him to the dict.
    #elif 'Nick' in userdata:
    elif event == "Change Nick":
        user = hexchat.strip(word[1])
        old = hexchat.strip(word[0])
        if old in last_seen:
            last_seen[user] = last_seen[old]
            del last_seen[old]
        else:
            last_seen[user] = [time(), 0]
    # If the user logged in before we did (no entry of him yet), don't display
    # his part messages
    if user not in last_seen:
        return hexchat.EAT_ALL
    # If the user has never spoken, or has spoken too long ago, eat his part
    # or join messages.
    if last_seen[user][1] == 0 or last_seen[user][0] + user_timeout < time():
        return hexchat.EAT_ALL


hooks_new = ["Your Message", "Channel Message", "Channel Msg Hilight",
             "Your Action", "Channel Action", "Channel Action Hilight"]
hooks_filter = ["Join", "Change Nick", "Part", "Part with Reason", "Quit"]
# hook_print_attrs is used for compatibility with my other scripts,
# since priorities are hook specific
for hook in hooks_new:
    hexchat.hook_print_attrs(hook, new_msg, hook, hexchat.PRI_HIGH)
for hook in hooks_filter:
    hexchat.hook_print_attrs(hook, filter_msg, hook, hexchat.PRI_HIGH)

print("\00304", __module_name__, "successfully loaded.\003")
