__module_name__ = "blinkonprivate"
__module_version__ = "1.0.0"
__module_description__ = "Blink tray icon whenever nick is mentioned in private window."
__module_author__ = "gpiccoli"

import hexchat

def privmsg(word, word_eol, userdata):
    if hexchat.get_info("nick") in word_eol[3]:
        hexchat.command("TRAY -i 5")
    return hexchat.EAT_NONE

hexchat.hook_server("PRIVMSG", privmsg)
