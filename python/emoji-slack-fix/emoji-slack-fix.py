# Replace all the horrible :slightly_smiling_face: rubbish that Slack inserts
# into horrible Unicode emoji symbols.
# Author: Andy Balaam
# License: CC0 https://creativecommons.org/publicdomain/zero/1.0/

# Requires https://pypi.python.org/pypi/emoji - I used 0.5.4
import emoji
import hexchat

__module_name__ = "slack-emojis"
__module_version__ = "1.0"
__module_description__ = "Translate emojis from Slack with colons into emojis"

print ("Loading slack-emojis")
chmsg = "Channel Message"
prmsg = "Private Message to Dialog"

def preprint(words, word_eol, userdata):
    txt = word_eol[1]
    replaced = emoji.emojize(txt, use_aliases=True)
    if replaced != txt:
        hexchat.emit_print(
            userdata["msgtype"],
            words[0],
            replaced.encode('utf-8'),
        )
        return hexchat.EAT_HEXCHAT
    else:
        return hexchat.EAT_NONE

hexchat.hook_print(chmsg, preprint, {"msgtype": chmsg})
hexchat.hook_print(prmsg, preprint, {"msgtype": prmsg})
