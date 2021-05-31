__module_name__ = "isbanned"
__module_author__ = "mniip"
__module_version__ = "0.8"
__module_description__ = "freenode-specific module that checks whether someone is banned on some channel"

"""
    Commands:
        /isbanned <channel> <user>
            Check whether <user> is banned on <channel>
        /ismuted <channel> <user>
            Check whether <user> is muted on <channel>
        /islisted <channel> <mode> <user>
            Check whether <user> is listed in <channel>'s
            <mode> list (can be b, q, e, or I)
        /isreset
            If something screws up, this resets the state to inactive

    <user> can either be a nickname, or a hostmask in the form
        nick!ident@host#gecos$account
    where some parts can be omitted. Strictly speaking the form is
        [nick] ['!' ident] ['@' host] ['#' gecos] ['$' account]
    If any part is omitted, it is assumed to be empty string, except for
    account: if the account part is omitted the user is assumed to be
    unidentified (as opposed to identified as empty string)

    Supports all kinds of features, misfeatures, and quirks freenode uses.
    Supports $a, $j, $r, $x, and $z extbans, and any edge cases of those.
    Supports CIDR bans, both IPv4 and IPv6, and the misfeature by which
    an invalid IP address is not parsed and zeroes are matched instead.
    Supports the +ikmrS modes. Supports the RFC2812 casemapping in patterns,
    which are, by the way, parsed without backtracking and thus effeciently.
"""

import hexchat
import socket, re, time

active = False
user = None
channel = None
orig_list = None
modes = None
whois = None
lists_left = 0
bans = []

ipv6_regex = re.compile(r"^0*[0-9a-fA-F]{1,4}$")
def parse_ipv6_word(w):
    m = ipv6_regex.match(w)
    if not m:
        raise ValueError("Invalid IPv6 octet")
    return int(m.group(0), 16)

ipv4_regex = re.compile(r"^(\d+)\.(\d+)\.(\d+)\.(\d+)$")
def parse_ip(ip, is_v4):
    if is_v4:
        m = ipv4_regex.match(ip)
        if m:
            try:
                o1 = int(m.group(1))
                o2 = int(m.group(2))
                o3 = int(m.group(3))
                o4 = int(m.group(4))
                if o1 < 256 and o2 < 256 and o3 < 256 and o4 < 256:
                    return o1 << 24 | o2 << 16 | o3 << 8 | o4
            except ValueError:
                pass
    else:
        edge = False
        if ip[:2] == "::":
            edge = True
            ip = "0" + ip
        if ip[-2:] == "::":
            edge = True
            ip = ip + "0"
        if ip.find("::") == -1:
            words = ip.split(":", 8)
            if len(words) == 8:
                try:
                    words = [parse_ipv6_word(w) for w in words]
                    ip = 0
                    for i in range(8):
                        ip |= words[i] << ((7 - i) * 16)
                    return ip
                except ValueError:
                    pass
        else:
            head, tail = ip.split("::", 1)
            headwords = head.split(":", 8)
            tailwords = tail.split(":", 8)
            if len(headwords) + len(tailwords) <= (8 if edge else 7):
                try:
                    headwords = [parse_ipv6_word(w) for w in headwords]
                    tailwords = [parse_ipv6_word(w) for w in tailwords]
                    words = headwords + [0] * (8 - len(headwords) - len(tailwords)) + tailwords
                    ip = 0
                    for i in range(8):
                        ip |= words[i] << ((7 - i) * 16)
                    return ip
                except ValueError:
                    pass

char_classes = {
        "[": r"[\[{]",
        "{": r"[{\[]",
        "|": r"[|\\]",
        "\\": r"[\\|]",
        "]": r"[\]}]",
        "}": r"[}\]]",
        "~": r"[~^]",
        "?": "."
    }
for c in "-_`^0123456789":
    char_classes[c] = c
for c in range(0, 26):
    lc = chr(ord("a") + c)
    uc = chr(ord("A") + c)
    char_classes[lc] = "[" + lc + uc + "]"
    char_classes[uc] = "[" + uc + lc + "]"

pass1_regex = re.compile(r"[?*]+")
def match_pattern(string, pattern):
    def pass1(m):
        w = m.group(0)
        return "?" * w.count("?") + ("" if w.find("*") == -1 else "*")
    pattern = pass1_regex.sub(pass1, pattern)

    last_pos = 0
    pieces = pattern.split("*")
    for i in range(len(pieces)):
        regex = []
        if i == 0:
            regex.append(r"^")
        for c in pieces[i]:
            regex.append(char_classes.get(c, "\\" + c))
        if i == len(pieces) - 1:
            regex.append(r"$")
        m = re.search("".join(regex), string[last_pos:])
        if m:
            last_pos += m.end()
            regex = []
        else:
            return False
    return True

def analyze():
    global active
    active = False
    nick, ident, host, gecos, account, ssl = whois
    found_modes = []
    hostile_modes = []
    for c in modes:
        if orig_list == "b":
            if c == "i" or c == "k" or (c == "r" and not account) or (c == "S" and not ssl):
                hostile_modes.append(c)
        elif orig_list == "q":
            if c == "m" or (c == "r" and not account):
                hostile_modes.append(c)
    if len(hostile_modes):
        found_modes.append("\x0302+%s\x0F in \x0306%s\x0F" % ("".join(hostile_modes), channel))
    def add_ban(b):
        found_modes.append("\x0302%s %s\x0F in \x0306%s\x0F set by \x0310%s\x0F on \x0308%s\x0F" % (b[1], b[0], b[2], b[3], time.ctime(int(b[4]))))
    for b in bans:
        ban = b[0][0] + b[0][1:].split("$", 1)[0]
        if ban[0] == "$":
            if ban == "$a":
                if account:
                    add_ban(b)
            elif ban == "$~a":
                if not account:
                    add_ban(b)
            elif ban[:3] == "$a:":
                if account and hexchat.nickcmp(account, ban[3:]) == 0:
                    add_ban(b)
            elif ban[:4] == "$~a:":
                if not account or hexchat.nickcmp(account, ban[4:]) != 0:
                    add_ban(b)
            elif ban[:4] == "$~j:":
                add_ban(b)
            elif ban[:3] == "$r:":
                if match_pattern(gecos, ban[3:]):
                    add_ban(b)
            elif ban[:4] == "$~r:":
                if not match_pattern(gecos, ban[4:]):
                    add_ban(b)
            elif ban[:3] == "$x:":
                for h in host:
                    if match_pattern("%s!%s@%s#%s" % (nick, ident, h, gecos), ban[3:]):
                        add_ban(b)
                        break;
            elif ban[:4] == "$~x:":
                found = False
                for h in host:
                    if match_pattern("%s!%s@%s#%s" % (nick, ident, h, gecos), ban[4:]):
                        found = True
                        break
                if not found:
                    add_ban(b)
            elif ban == "$z":
                if ssl:
                    add_ban(b)
            elif ban == "$~z":
                if not ssl:
                    add_ban(b)
            else:
                hexchat.prnt("\x0304Unknown extban: " + b[0])
        else:
            v = ban.split("@", 1)
            bhost = v[1] if len(v) == 2 else ""
            v = v[0].split("!", 1)
            bident = v[1] if len(v) == 2 else ""
            bnick = v[0]
            if match_pattern(nick, bnick) and match_pattern(ident, bident):
                found = False
                for h in host:
                    if match_pattern(h, bhost):
                        found = True
                        add_ban(b)
                        break
                if not found:
                    try:
                        ip, width = bhost.rsplit("/", 1)
                        width = int(re.match("-?[0-9]*", width).group(0)) % 2**32
                        if width > 0:
                            is_v4 = ip.find(":") == -1
                            shift = max((32 if is_v4 else 128) - width, 0)
                            ip = parse_ip(ip, is_v4)
                            for h in host:
                                if (h.find(":") == -1) == is_v4:
                                    if ip == None:
                                        add_ban(b)
                                        break
                                    h = parse_ip(h, is_v4)
                                    if h == None:
                                        continue
                                    if ip >> shift == h >> shift:
                                        add_ban(b)
                                        break
                    except ValueError:
                        pass
    if len(found_modes):
        if orig_list == "b":
            hexchat.prnt("The following are preventing \x0310%s\x0F from joining \x0306%s\x0F:" % (user, channel))
        elif orig_list == "q":
            hexchat.prnt("The following are preventing \x0310%s\x0F from speaking in \x0306%s\x0F:" % (user, channel))
        else:
            hexchat.prnt("The following \x0302+%s\x0F modes affect \x0310%s\x0F in \x0306%s\x0F:" % (orig_list, user, channel))
        for m in found_modes:
            hexchat.prnt(m)
    else:
        if orig_list == "b":
            hexchat.prnt("Nothing is preventing \x0310%s\x0F from joining \x0306%s\x0F" % (user, channel))
        elif orig_list == "q":
            hexchat.prnt("Nothing is preventing \x0310%s\x0F from speaking in \x0306%s\x0F" % (user, channel))
        else:
            hexchat.prnt("No \x0302+%s\x0F modes affect \x0310%s\x0F in \x0306%s\x0F" % (orig_list, user, channel))

def reset(w, we, udata):
    global active
    active = False
    return hexchat.EAT_ALL

def lookup_host(host):
    hexchat.prnt("\x0302Resolving '%s'" % (host))
    try:
        ips = list(set([host] + socket.gethostbyname_ex(host)[2]))
        hexchat.prnt("\x0302IPs: %s" % (repr(ips)))
        return ips
    except (socket.gaierror, socket.herror):
        hexchat.prnt("\x0302Found nothing, will use %s" % (repr([host])))
        return [host]


def query_list(channel, mode):
    global lists_left
    lists_left += 1
    hexchat.command("quote MODE %s" % (channel))
    hexchat.command("quote MODE %s %s" % (channel, mode))

def query_whois(nick):
    hexchat.command("quote WHOIS %s" % (nick))

def ignored(w, we, udata):
    if active:
        return hexchat.EAT_ALL

def modes(w, we, udata):
    global modes
    if active:
        if "s" in w[4]:
            hexchat.prnt("\x0302Channel %s is +s, report may be incomplete" % (w[3]))
        if hexchat.nickcmp(w[3], channel) == 0:
            modes = w[4]
            if lists_left == 0 and whois:
                analyze()
        return hexchat.EAT_ALL

def list_entry(w, we, udata):
    global lists_left
    if active:
        if udata == "+q":
            del w[4]
        if w[4][:3] == "$j:":
            if hexchat.nickcmp(w[3], channel) == 0:
                query_list(w[4][3:].split("$", 1)[0], "b")
        else:
            bans.append((w[4], udata, w[3], w[5], w[6]))
        return hexchat.EAT_ALL

def list_end(w, we, udata):
    global lists_left
    if active:
        lists_left -= 1
        if lists_left == 0 and whois and modes:
            analyze()
        return hexchat.EAT_ALL

def no_modes(w, we, udata):
    global modes, lists_left
    if active:
        hexchat.prnt("\x0304Attempted to get modes for a nickname, did you put the arguments in the wrong order?")
        if not modes:
            modes = "+"
            if lists_left == 0 and whois:
                analyze()
        else:
            lists_left -= 1
            if lists_left == 0 and whois and modes:
                analyze()
        return hexchat.EAT_ALL

def mode_error(w, we, udata):
    global modes, lists_left
    if active:
        hexchat.prnt("\x0304Something went wrong with the modes, report may be incomplete")
        if not modes:
            modes = "+"
            if lists_left == 0 and whois:
                analyze()
        else:
            lists_left -= 1
            if lists_left == 0 and whois and modes:
                analyze()
        return hexchat.EAT_ALL

def no_list(w, we, udata):
    global lists_left, modes
    if active:
        if hexchat.nickcmp(w[3], channel) == 0 and not modes:
            hexchat.prnt("\x0304Could not obtain modes for %s, report may be incomplete" % (w[3]))
            modes = "+"
            if lists_left == 0 and whois:
                analyze()
        else:
            hexchat.prnt("\x0304Could not obtain list for %s, report may be incomplete" % (w[3]))
            lists_left -= 1
            if lists_left == 0 and whois and modes:
                analyze()
            return hexchat.EAT_ALL

wh = None
ac = None
ssl = None
def whois_start(w, we, udata):
    global wh, ac, ssl
    if active:
        wh = (w[3], w[4], lookup_host(w[5]), we[7][1:])
        ac = None
        ssl = False
        return hexchat.EAT_ALL

def whois_ssl(w, we, udata):
    global ssl
    if active:
        ssl = True
        return hexchat.EAT_ALL

def whois_account(w, we, udata):
    global ac
    if active:
        ac = w[4]
        return hexchat.EAT_ALL

def whois_end(w, we, udata):
    global whois, active, wh
    if active:
        if wh:
            whois = (wh[0], wh[1], wh[2], wh[3], ac, ssl)
            wh = None
        else:
            hexchat.prnt("\x0304Whois failed, aborting!")
            active = False
        if lists_left == 0 and modes:
            analyze()
        return hexchat.EAT_ALL

def start_search(ch, u, mode):
    global active, channel, user, modes, whois, lists_left, bans, orig_list
    whois = None
    orig_list = mode
    channel = ch
    user = u
    if "!" in user or "@" in user or "#" in user or "$" in user:
        v = user.split("$", 1)
        account = v[1] if len(v) == 2 else None
        v = v[0].split("#", 1)
        rname = v[1] if len(v) == 2 else ""
        v = v[0].split("@", 1)
        host = v[1] if len(v) == 2 else ""
        v = v[0].split("!", 1)
        ident = v[1] if len(v) == 2 else ""
        nick = v[0]
        whois = (nick, ident, lookup_host(host), rname, account, False)
    modes = None
    lists_left = 0
    bans = []
    active = True
    query_list(channel, mode)
    if not whois:
        query_whois(user)

def isbanned(w, we, udata):
    start_search(w[1], we[2], "b")
    return hexchat.EAT_ALL

def ismuted(w, we, udata):
    start_search(w[1], we[2], "q")
    query_list(w[1], "b")
    return hexchat.EAT_ALL

def islisted(w, we, udata):
    start_search(w[1], we[3], w[2].lstrip("+"))
    return hexchat.EAT_ALL

hexchat.hook_server("329", ignored)
hexchat.hook_server("276", ignored)
hexchat.hook_server("317", ignored)
hexchat.hook_server("378", ignored)
hexchat.hook_server("319", ignored)
hexchat.hook_server("312", ignored)
hexchat.hook_server("324", modes)
hexchat.hook_server("367", list_entry, "+b")
hexchat.hook_server("728", list_entry, "+q")
hexchat.hook_server("346", list_entry, "+I")
hexchat.hook_server("348", list_entry, "+e")
hexchat.hook_server("368", list_end)
hexchat.hook_server("729", list_end)
hexchat.hook_server("347", list_end)
hexchat.hook_server("349", list_end)
hexchat.hook_server("502", no_modes)
hexchat.hook_server("221", no_modes)
hexchat.hook_server("472", mode_error)
hexchat.hook_server("501", mode_error)
hexchat.hook_server("403", no_list)
hexchat.hook_server("482", no_list)
hexchat.hook_server("311", whois_start)
hexchat.hook_server("671", whois_ssl)
hexchat.hook_server("330", whois_account)
hexchat.hook_server("318", whois_end)
hexchat.hook_command("isbanned", isbanned)
hexchat.hook_command("ismuted", ismuted)
hexchat.hook_command("islisted", islisted)
hexchat.hook_command("isreset", reset)
