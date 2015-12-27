__module_name__ = "at"
__module_version__ = "0.0.0"
__module_description__ = "Prefix nickname completions with the @ sign"

# @-completion will be applied to networks matching the below regex
affected_networks = r"^.*$"

import hexchat
import re

def keypress(w, we, u):
    if re.search(affected_networks, hexchat.get_info("network")):
        key, state, key_str, str_len = w
        if int(key) == 65289: # <Tab>
            inputbox = hexchat.get_info("inputbox")
            pos = hexchat.get_prefs("state_cursor")
            text, suffix = inputbox[:pos], inputbox[pos:]
            prefix, space, word = text.rpartition(" ")
            if len(word):
                prefix += space
                if word[0] == '#':
                    return hexchat.EAT_NONE # let the built-in completion handle channels
                if word[0] == '@':
                    word = word[1:]
                users = []
                for u in hexchat.get_list("users"):
                    if not hexchat.nickcmp(u.nick[:len(word)], word):
                        users.append((u.nick, u.lasttalk))
                for c in hexchat.get_list("channels"):
                    if c.context == hexchat.get_context():
                        if c.type == 3:
                            if not hexchat.nickcmp(c.channel[:len(word)], word):
                                users.append((c.channel, 0)) # if we're in a dialog, include the targer user
                if len(users):
                    if len(users) == 1:
                        completion = "@" + users[0][0] + " "
                    else:
                        if hexchat.get_prefs("completion_sort") == 1:
                            users = sorted(users, key = lambda x: -x[1])
                        else:
                            users = sorted(users, key = lambda x: x[0].lower())
                        nicks = [u[0] for u in users]
                        print(" ".join(nicks))
                        common = None # longest common prefix
                        for nick in nicks:
                            if common == None:
                                common = word + nick[len(word):] # copy the case of characters entered by the user
                            else:
                                while hexchat.nickcmp(nick[:len(common)], common):
                                    common = common[:-1]
                        for nick in nicks:
                            if not hexchat.nickcmp(nick, word):
                                common = nick # if we have an exact match, ignore the case of user's characters
                        completion = "@" + common
                    hexchat.command("settext " + prefix + completion + suffix)
                    hexchat.command("setcursor " + str(len(prefix) + len(completion)))
                return hexchat.EAT_ALL
            else:
                prevword = prefix.rpartition(" ")[2]
                if len(prevword) and prevword[0] == '@':
                    return hexchat.EAT_ALL # don't let the built-in completion kick in if we just completed a nick
                else:
                    return hexchat.EAT_NONE
        else:
            return hexchat.EAT_NONE

hexchat.hook_print("Key Press", keypress)
