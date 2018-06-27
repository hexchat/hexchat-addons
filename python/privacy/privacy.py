import hexchat

__module_name__ = "privacy"
__module_version__ = "1.0"
__module_description__ = "Privacy helper plugin"
__module_author__ = "Viktor Villainov"

HELP_TEXT = """
Privacy helper plugin makes your client settings \"anonymous\" and allows to 
connect to Tor and I2P servers easier.

    /PRIVACY help
        Show this help message

    /PRIVACY network [tor|i2p]
        Switch between Tor and I2P networks

    /PRIVACY set <option> <value>

        Available options:

        privacy_proxy     host:port of Socks5 proxy (default: auto)
        privacy_no_leaks  0|1 (default: 1)
        privacy_no_logs   0|1 (default: 1)
"""

DEFAULT_PROXY = {"clearnet": "", "tor": "127.0.0.1:9050", "i2p": "127.0.0.1:4447"}

def do_help(): print(HELP_TEXT)

def switch_network(word):
    if len(word) == 3 and word[2] in DEFAULT_PROXY:
        hexchat.set_pluginpref("privacy_network", word[2])
        hexchat.set_pluginpref("privacy_proxy", DEFAULT_PROXY[word[2]])
        configure_hexchat()
        print("Switched network to", word[2])
    else:
        return do_help()

def set_option(word):
    if len(word) == 2:
        for l in [x for x in hexchat.list_pluginpref() if x.startswith("privacy_")]:
            print(l, "=", hexchat.get_pluginpref(l))
    elif len(word) == 4:
        k, v = word[2], word[3]
        hexchat.set_pluginpref(k, v)
        configure_hexchat()
        print(k, "=", v)
    else:
        return do_help()

def configure_hexchat():
    if hexchat.get_pluginpref("privacy_network") is None:
        hexchat.set_pluginpref("privacy_network", "clearnet")
    if hexchat.get_pluginpref("privacy_proxy") is None:
        hexchat.set_pluginpref("privacy_proxy", 
            DEFAULT_PROXY[hexchat.get_pluginpref("privacy_network").lower()])
    if hexchat.get_pluginpref("privacy_no_leaks") is None:
        hexchat.set_pluginpref("privacy_no_leaks", "1")
    if hexchat.get_pluginpref("privacy_no_logs") is None:
        hexchat.set_pluginpref("privacy_no_logs", "1")

    options = [
        ("irc_user_name",   "user"),
        ("irc_real_name",   "user"),
        ("irc_nick1",       "user"),
        ("irc_nick2",       "user_"),
        ("irc_nick3",       "user__"),
        ("gui_slist_skip",  "1"),
    ]

    proxy = hexchat.get_pluginpref("privacy_proxy").split(":")
    if proxy[0]:
        options += [
            ("net_proxy_auth", "0"),
            ("net_proxy_host", proxy[0]),
            ("net_proxy_port", proxy[1]),
            ("net_proxy_type", "3"),
            ("net_proxy_use",  "0"),
        ]
    else:
        options += [("net_proxy_type", "0"),]

    if hexchat.get_pluginpref("privacy_no_logs") == 1:
        options += [("irc_logging", "0"), ("text_replay", "0"),]

    for k, v in options:
        hexchat.command("SET -quiet {} ={}".format(k, v))

    for k in ["away_reason", "irc_part_reason", "irc_quit_reason"]:
        hexchat.command("SET -e -quiet {}".format(k))

    if hexchat.get_pluginpref("privacy_no_leaks") == 1:
        hexchat.command("IGNORE * CTCP DCC QUIET")
        hexchat.command("IGNORE \"*!*@*\" CTCP DCC QUIET")

ACTIONS = {
    "set": set_option,
    "network": switch_network,
}

def privacy_cb(word, word_eol, userdata):
    if len(word) >= 2 and word[1] in ACTIONS:
        ACTIONS[word[1].lower()](word)
    else:
        do_help()

    return hexchat.EAT_ALL

if __name__ == "__main__":
    configure_hexchat()
    hexchat.hook_command("PRIVACY", privacy_cb, help=HELP_TEXT)
    hexchat.prnt("Privacy helper plugin loaded! Type --> /PRIVACY help")

    hexchat.command("MENU ADD Privacy")
    hexchat.command('MENU ADD "Privacy/Set network"')
    hexchat.command('MENU ADD "Privacy/Set network/I2P" "PRIVACY network i2p"')
    hexchat.command('MENU ADD "Privacy/Set network/Tor" "PRIVACY network tor"')
    hexchat.command('MENU ADD "Privacy/Set network/Clearnet" "PRIVACY network clearnet"')
