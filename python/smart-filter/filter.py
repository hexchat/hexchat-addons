__module_name__ = 'Filter'
__module_version__ = '1.0'
__module_description__ = 'Filters join/part messages'

import xchat
from time import time

last_seen = {} # For each entry: the key is the user's nickname, the entry
               # is a list: element 0: last seen time
               #            element 1: 0 if the user never spoke, 1 otherwise
user_timeout = 600 # If the user hasn't spoken for this amount of seconds, his
                   # join/part messages won't be shown

def new_msg(word, word_eol, userdata):
    """Handles normal messages.
    
    Unless this is the first user's message since he joined, the message will
    not be altered. Otherwise, a '(logged in Xs ago)' message will be appended.
    
    """
    user = xchat.strip(word[0])
    # If the user logged in before we did (which means the Join part of
    # filter_msg didn't take effect), add him to the dict.
    try:
        last_seen[user]
    except KeyError:
        last_seen[user]= [time(), 1]
    # If the user has never spoken before, let us know when he logged in.
    if last_seen[user][1] == 0:
        time_diff = time() - last_seen[user][0]
        xchat.prnt("%s\t\017%s \00307(logged in %ss ago)" % (word[0], word[1],
                                                          int(time_diff)))
        last_seen[user]= [time(), 1]
        return xchat.EAT_XCHAT

def filter_msg(word, word_eol, userdata):
    """Filters join and part messages"""
    user = xchat.strip(word[0])
    # If the user just joined, add him to the dict and mark him as such
    if userdata == 'Join':
        last_seen[user] = [time(), 0]
        return xchat.EAT_XCHAT
    # If the user changed his nick, check if we've been tracking him before
    # and transfer his stats if so. Otherwise, add him to the dict.
    elif userdata == 'Nick':
        user = xchat.strip(word[1])
        try:
            last_seen[user] = last_seen[xchat.strip(word[0])]
            del last_seen[xchat.strip(word[0])]
        except KeyError:
            last_seen[user] = [time(), 0]
    # If the user logged in before we did (no entry of him yet), don't display
    # his part messages
    try:
        last_seen[user]
    except KeyError:
        return xchat.EAT_XCHAT
    # If the user has never spoken, or has spoken too long ago, eat his part
    # or join messages.
    if last_seen[user][1] == 0 or last_seen[user][0] + user_timeout < time():
        return xchat.EAT_XCHAT


xchat.hook_print('Channel Message', new_msg)
xchat.hook_print('Channel Msg Hilite', new_msg)
xchat.hook_print('Join', filter_msg, 'Join')
xchat.hook_print('Change Nick', filter_msg, 'Nick')
xchat.hook_print('Part', filter_msg)
xchat.hook_print('Part with Reason', filter_msg)
xchat.hook_print('Quit', filter_msg)

print "\00304", __module_name__, "successfully loaded.\003"
