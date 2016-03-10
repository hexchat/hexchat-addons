__module_name__ = "statusmsg"
__module_version__ = "1.1.0"
__module_description__ = "Highlight statusmsg (+#channel, @#channel, etc) messages in a distinct way."
__module_author__ = "mniip"

import hexchat

lastTarget = None
lastSource = None

def privmsg(w, we, u):
    global lastTarget, lastSource
    lastTarget = w[2]
    lastSource = w[0].split("!", 1)[0].lstrip(":")
    return hexchat.EAT_NONE

recursion = False
def msg_event(w, we, event):
    global recursion
    if recursion:
        return hexchat.EAT_NONE
    source = hexchat.strip(w[0])
    target = hexchat.get_info("channel")
    if hexchat.nickcmp(source, lastSource) == 0:
        if hexchat.nickcmp(target, lastTarget[-len(target):]) == 0:
            status = lastTarget[:-len(target)]
            if len(status):
                if not any(c.isalpha() or c.isdigit() for c in status):
                    if len(w) > 2:
                        w[2] = "[" + status + "]" + w[2]
                    else:
                        w.append("[" + status + "]")
                    recursion = True
                    hexchat.emit_print(event, *w)
                    recursion = False
                    return hexchat.EAT_ALL
    return hexchat.EAT_NONE

hexchat.hook_server("PRIVMSG", privmsg)
for e in ("Channel Message", "Channel Msg Hilight", "Channel Action", "Channel Action Hilight"):
    hexchat.hook_print(e, msg_event, e)
