__module_name__ = "sharedchannels"
__module_version__ = "0.3.4"
__module_description__ = "Discover which users in one channel share other channels with you"
"""
SharedChannels.py plugin for XChat
by Jason "zcat" Farrell (farrellj@gmail.com), 2007
Distributed under the terms of the GNU General Public License, v2 or later
"""
import xchat

#################################################

chantype = {"server": 1, "channel": 2, "dialog": 3}

def usage():
    print """\
Usage: /sharedchannels #comparison_channel
 Shows which users in #comparison_channel are also in your other channels (on the same network.) Useful for finding bots, discovering what users share your interests, or seeing who might have seen you say something in other channels."""

def sharedchannels_cb(word, word_eol, userdata):
    mynickname = xchat.get_context().get_info("nick")
    excluded_users = [mynickname, 'ChanServ']      # a list of users to ignore, including your nickname(s)
    if len(word) < 2 or word[1][0] != '#':
        usage(); return xchat.EAT_XCHAT
    chan1 = word[1]
    cc = xchat.find_context(channel=chan1)
    if not cc:
        print "Oops - you don't seem to be in channel", chan1
        return xchat.EAT_XCHAT

    chan1server = cc.get_info('server')
    userlist = {}
    for chan in xchat.get_list('channels'):
        if chan.server == chan1server and chan.type == chantype['channel']:
            for user in chan.context.get_list('users'):
                if user.nick not in excluded_users:
                    userlist.setdefault(chan.channel, []).append(user.nick)

    print "###############################################################################"  # 79
    print "# " + ("The users in %s share the following channels with you (%s)" % (chan1, mynickname)).center(79-4) + " #"
    print "###############################################################################"  # 79
    for chan in sorted(userlist.keys()):
        if chan != chan1:
            usersincommon = sorted(set(userlist[chan1]) & set(userlist[chan]))
            if usersincommon:
                print "%15s:\t%s" % (chan, ', '.join(usersincommon))
    print "###############################################################################"  # 79

    return xchat.EAT_XCHAT

xchat.hook_command("sharedchans", sharedchannels_cb)
xchat.prnt(__module_name__ + ' v' + __module_version__ + ' loaded.')
