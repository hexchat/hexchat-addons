__module_name__ = "cd"
__module_author__ = "mniip"
__module_version__ = "0.2.1"
__module_description__ = "operator helper capable of executing composable actions"

"""
    Commands:
        /o <actions>
            The core of the script: executes <actions> in current channel. The
            action syntax is described below.
        /co <actions>
            Request OP from ChanServ and then execute <actions>.
        /d <actions>
            Execute <actions> and then deop yourself.
        /cd <actions>
            Request OP from ChanServ, execute <actions>, and then deop yourself.
        /cd_log
            Open a tab containing debug logs of the script.
        /cd_flush
            In case of someting breaking, this is the command that aborts
            everything.
        /cd_status
            Print events the script is currently waiting for.

    Action syntax:
        An action is either a mode (plus or minus followed by a letter), or the
        letters 'k', 'i', or 'r' alone. If a different letter is encountered, it
        is assumed that it is a mode, and the sign is inherited from the
        previous mode within the current action, or set to '+' if it was the
        first.

        The 'k' action executes a kick. It is followed by a target and
        optionally a reason. A default reason can be configured below.

        The 'i' action executes an invite. It is followed by a target.

        The 'r' action executes a REMOVE (force-part). It is followed by a
        target and optinally a reason.

        Mode actions can be followed by a parameter (also interpreted as a
        target), optionally prefixed by a WHOIS selector, and optionally
        suffixed by a redirection. A WHOIS selector runs a WHOIS query on the
        target (presumingly a nickname) and uses the resulting fields to
        construct a banmask. The selector is either the symbol ':', or a
        combination of '!', '~', and '@'. The ':' selector produces an account
        banmask: '$a:account'. Other selectors substitute respective fields into
        the '*!*@*' banmask. '@' replaces the host part of the banmask with the
        actual host provided by the WHOIS reply. Likewise, '~' substitutes
        ident, and '!' substitutes nickname. For example if you want to ban
        someone by nickname and host, you'd run
            /o +b !@ someone
        The redirection parameter corresponds to $#channel redirection bans, and
        consists of a dollar followed by a channel name.

        Multiple actions can be specified, using a semicolon-separated list.
        Moreover, multiple actions can use the same argument, for example the
        following simultaneously bans a user by host, and kicks them:
            /o +bk @ user Kick reason.
        The '+b' action ignores 'Kick reason', and the 'k' action ignores the
        '@' WHOIS selector.

        On top of that, a target is either a single word (nickname), or a
        whitespace-separated list of words (nicknames) surrounded by '(' and
        ')'. For example, you can voice multiple people at once with:
            /o +v (foo bar)

        The syntax is whitespace-permissive, with the only exception being that
        when multiple actions reuse the same argument, they should be 'glued'
        into one word to avoid ambiguities. As such, the following commands are
        the same:
            /o +bk@(foo bar)$#redirect Reason;+q!user
            /o +bk @ ( foo bar ) $ #redirect Reason ; +q ! user

    Copyright (c) 2015, mniip

    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

        * Redistributions of source code must retain the above copyright
          notice, this list of conditions and the following disclaimer.

        * Redistributions in binary form must reproduce the above
          copyright notice, this list of conditions and the following
          disclaimer in the documentation and/or other materials provided
          with the distribution.

        * Neither the name of mniip nor the names of other
          contributors may be used to endorse or promote products derived
          from this software without specific prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
    A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
    OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
    SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
    LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
    DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
    THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
    (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
    OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
"""

defaultKickReason = "Your behavior is not conducive to the desired environment."
defaultModesPerLine = 3
hardModeLimit = 16
fixModes = True
logLevel = 1
logPrefixes = ["\x0302(==) ", "\x0303(**) ", "\x0304(EE) "]
logTab = "(cd)"
chanServFailure = r"not authorized|is not registered|is not on|is closed"
ignoreVersions = r"(?!)"

try:
    import xchat
    hexchat = xchat
except ImportError:
    import hexchat
import re, time

logHistory = []
def log(level, string):
    t = time.localtime()
    entry = logPrefixes[level] + string
    logHistory.append((t, entry))
    if level >= logLevel and hexchat.get_info("channel") != logTab:
        hexchat.prnt(entry)
    context = hexchat.find_context(channel = logTab)
    if context:
        context.prnt(time.strftime("[%H:%M:%S] ", t) + entry)
log(1, __module_name__ + " " + __module_version__ + " initialising")

def commandLog(w, we, u):
    context = hexchat.find_context(channel = logTab)
    if context:
        context.command("clear")
        context.command("gui focus")
    else:
        oldSetting = hexchat.get_prefs("gui_tab_newtofront")
        hexchat.command("set -quiet gui_tab_newtofront 1")
        hexchat.command("query " + logTab)
        hexchat.command("set -quiet gui_tab_newtofront " + str(oldSetting))
        context = hexchat.find_context(channel = logTab)
    for t, entry in logHistory:
        context.prnt(time.strftime("[%H:%M:%S] ", t) + entry)
    return hexchat.EAT_ALL

def netId(ctx = None):
    if ctx == None or ctx == hexchat.get_context():
        return hexchat.get_prefs("id")
    else:
        for c in hexchat.get_list("channels"):
            if c.context == ctx:
                return c.id
        return "?"

def sendCommand(ctx, command):
    log(0, "[" + str(netId(ctx)) + "] quote " + command)
    ctx.command("quote " + command)

class Async:
    def __init__(self, target):
        self.target = target
        gen = self.trampoline()
        next(gen)
        self.thread = gen
        try:
            next(gen)
        except StopIteration:
            pass

    def trampoline(self):
        yield
        for y in self.target(self.thread): yield y

class Promise:
    def __init__(self, thread):
        self.thread = thread

    def wait(self):
        while not hasattr(self, "value"):
            yield

    def fulfill(self, value):
        self.value = value
        try:
            next(self.thread)
        except StopIteration:
            pass

class Struct:
    def __init__(self, **kw):
        self.__dict__.update(kw)

class Whois(Struct): pass

class WhoisPromise(Promise):
    promises = []
    def __init__(self, thread, ctx, nick):
            Promise.__init__(self, thread)
            self.ctx = ctx
            self.nick = nick
            WhoisPromise.promises.append(self)
            sendCommand(ctx, "WHOIS :" + self.nick)

    @staticmethod
    def propose(id, whois):
        def filt(p):
            if hexchat.nickcmp(p.nick, whois.nick) == 0 and netId(p.ctx) == id:
                log(0, "[" + str(id) + "] Received WHOIS for " + p.nick)
                p.fulfill(whois)
                return False
            else:
                return True
        WhoisPromise.promises = list(filter(filt, WhoisPromise.promises))

    lastWhois = {}

    @staticmethod
    def ignoreIfQueued(w, we, u):
        id = netId()
        if id in WhoisPromise.lastWhois:
            whois = WhoisPromise.lastWhois[id]
            for p in WhoisPromise.promises:
                if hexchat.nickcmp(p.nick, whois.nick) == 0 and netId(p.ctx) == id:
                    log(0, "[" + str(id) + "] " + " ".join(w))
                    return hexchat.EAT_ALL
        return hexchat.EAT_NONE

    @staticmethod
    def handler311(w, we, u):
        WhoisPromise.lastWhois[netId()] = Whois(nick = w[3], ident = w[4], host = w[5], account = None, failed = False)
        return WhoisPromise.ignoreIfQueued(w, we, u)

    @staticmethod
    def handler330(w, we, u):
        id = netId()
        if id in WhoisPromise.lastWhois:
            WhoisPromise.lastWhois[id].account = w[4]
        return WhoisPromise.ignoreIfQueued(w, we, u)

    @staticmethod
    def handler318(w, we, u):
        ret = WhoisPromise.ignoreIfQueued(w, we, u)
        id = netId()
        if id in WhoisPromise.lastWhois:
            WhoisPromise.propose(id, WhoisPromise.lastWhois[id])
            del WhoisPromise.lastWhois[id]
        else:
            WhoisPromise.propose(id, Whois(nick = w[3], failed = True))
        return ret

class ChanServPromise(Promise):
    promises = []
    def __init__(self, thread, ctx, channel):
            Promise.__init__(self, thread)
            self.ctx = ctx
            self.channel = channel
            ChanServPromise.promises.append(self)
            sendCommand(ctx, "PRIVMSG ChanServ :OP " + self.channel)

    @staticmethod
    def handlerMODE(w, we, u):
        source = w[0][1:].split("!", 1)[0]
        if source == "ChanServ":
            mode = w[3]
            if mode == "+o":
                nick = w[4]
                if hexchat.nickcmp(nick, hexchat.get_info("nick")) == 0:
                    channel = w[2]
                    id = netId()
                    def filt(p):
                        if hexchat.nickcmp(p.channel, channel) == 0 and netId(p.ctx) == id:
                            p.fulfill(True)
                            return False
                        else:
                            return True
                    ChanServPromise.promises = list(filter(filt, ChanServPromise.promises))

    @staticmethod
    def handlerNOTICE(w, we, u):
        source = w[0][1:].split("!", 1)[0]
        text = we[3]
        if source == "ChanServ" and re.search(chanServFailure, text):
            id = netId()
            def filt(p):
                if netId(p.ctx) == id:
                    p.fulfill(False)
                    return False
                else:
                    return True
            ChanServPromise.promises = list(filter(filt, ChanServPromise.promises))

def commandFlush(w, we, u):
    WhoisPromise.promises = []
    WhoisPromise.lastWhois = {}
    ChanServPromise.promises = []
    log(1, "Flushed ChanServ and WHOIS threads")
    return hexchat.EAT_ALL

def commandStatus(w, we, u):
    for p in ChanServPromise.promises:
        hexchat.prnt("[" + str(netId(p.ctx)) + "] Waiting for ChanServ in " + p.channel)
    for p in WhoisPromise.promises:
        hexchat.prnt("[" + str(netId(p.ctx)) + "] Waiting for WHOIS reply for " + p.nick)
    return hexchat.EAT_ALL

versions = {}

if fixModes:
    for c in hexchat.get_list("channels"):
        if c.type == 1 and not re.match(ignoreVersions, c.network):
            versions[netId(c.context)] = {}
            sendCommand(c.context, "VERSION")

def handler005(w, we, u):
    id = netId()
    if id not in versions:
        versions[id] = {}
    for i in range(3, len(w)):
        if len(w[i]) and w[i][0] == ':':
            break
        if '=' in w[i]:
            key, value = w[i].split('=', 1)
            if key == "MODES":
                try:
                    versions[id]["maxModes"] = int(value)
                except ValueError:
                    pass
            elif key == "CHANMODES":
                classes = value.split(',')
                if len(classes) >= 4:
                    versions[id]["listModes"] = classes[0]
                    versions[id]["alwaysArgModes"] = classes[1]
                    versions[id]["setArgModes"] = classes[2]
                    versions[id]["neverArgModes"] = classes[3]
            elif key == "PREFIX":
                if value[0] == '(':
                    ret = value[1:].split(')', 1)
                    versions[id]["statusModes"] = ret[0]

class Action(Struct): pass
class KickAction(Action): pass
class InviteAction(Action): pass
class RemoveAction(Action): pass

class ModeAction(Action):
    @staticmethod
    def append(list, mode):
        if len(list):
            a = list[-1]
            if isinstance(a, ModeAction) and a.channel == mode.channel:
                a.modes.extend(mode.modes)
                return
        list.append(mode)

class WhoisArg(Struct):
    def substitute(self, whois):
        if ":" in self.whoiser:
            mask = "$a:" + (whois.account or "")
        else:
            mask = (whois.nick if "!" in self.whoiser else "*") + "!" + (whois.ident if "~" in self.whoiser else "*") + "@" + (whois.host if "@" in self.whoiser else "*")
        if self.forward:
            mask += "$" + self.forward
        return mask

def parseActions(channel, input):
    actions = []
    for action in input.split(";"):
        action = action.lstrip()
        commands, args = re.match(r"^\s*([a-zA-Z+-=]*)(.*)$", action).groups()
        args = args.lstrip()
        wh, rest = re.match(r"^([:!~@\s]*)(.*)$", args).groups()
        if ":" in wh:
            whoiser = ":"
        else:
            whoiser = ""
            if "!" in wh:
                whoiser += "!"
            if "~" in wh:
                whoiser += "~"
            if "@" in wh:
                whoiser += "@"
        rest = rest.lstrip()
        targ, rest = re.match(r"^(\([^)]*\)?|\$*[^\s$]*)(.*)$", rest).groups()
        if len(targ) and targ[0] == '(':
            targets = targ[1:].rstrip(')').split()
        else:
            targets = [targ]
        rest = rest.lstrip()
        forward = None
        m = re.match(r"^\$\s*(\S+)(.*)$", rest)
        if m:
            forward, rest = m.groups()
        extra = rest.lstrip()
        lastSign = "+"
        for command in re.findall(r"[+-=]?[a-zA-Z]", commands):
            if command == "k":
                for nick in targets:
                    actions.append(KickAction(channel = channel, nick = nick, reason = extra))
            elif command == "i":
                for nick in targets:
                    actions.append(InviteAction(channel = channel, nick = nick))
            elif command == "r":
                for nick in targets:
                    actions.append(RemoveAction(channel = channel, nick = nick, reason = extra))
            else:
                if command[0] not in ["+", "-", "="]:
                    command = lastSign + command
                else:
                    lastSign = command[0]
                for nick in targets:
                    if whoiser != "":
                        modeArg = WhoisArg(nick = nick, whoiser = whoiser, forward = forward)
                    elif nick != "":
                        modeArg = nick + "$" + forward if forward else nick
                    else:
                        modeArg = None
                    ModeAction.append(actions, ModeAction(channel = channel, modes = [(command, modeArg)]))
    return actions

def renderActions(actions):
    ret = []
    for a in actions:
        if isinstance(a, KickAction):
            ret.append("k " + a.nick + (" " + a.reason if a.reason else ""))
        elif isinstance(a, InviteAction):
            ret.append("i " + a.nick)
        elif isinstance(a, RemoveAction):
            ret.append("r " + a.nick + (" " + a.reason if a.reason else ""))
        elif isinstance(a, ModeAction):
            for mode, arg in a.modes:
                if isinstance(arg, WhoisArg):
                    ret.append(mode + " " + arg.whoiser + " " + arg.nick + (" $ " + arg.forward if arg.forward else ""))
                else:
                    ret.append(mode + (" " + arg if arg else ""))
    return " ; ".join(ret)

def executeActions(ctx, actions):
    id = netId(ctx)
    if id in versions:
        maxModes = versions[id].get("maxModes", defaultModesPerLine)
    else:
        maxModes = defaultModesPerLine
    for a in actions:
        if isinstance(a, KickAction):
            sendCommand(ctx, "KICK " + a.channel + " " + a.nick + " :" + (a.reason or defaultKickReason))
        elif isinstance(a, InviteAction):
            sendCommand(ctx, "INVITE " + a.nick + " " + a.channel)
        elif isinstance(a, RemoveAction):
            sendCommand(ctx, "REMOVE " + a.channel + " " + a.nick + (" :" + a.reason if a.reason else ""))
        elif isinstance(a, ModeAction):
            modeString = []
            argString = []
            for mode, arg in a.modes:
                if (arg != None and len(argString) >= maxModes) or len(modeString) >= hardModeLimit:
                    sendCommand(ctx, "MODE " + a.channel + " " + "".join(modeString) + " " + " ".join(argString))
                    modeString = []
                    argString = []
                if isinstance(arg, WhoisArg):
                    for y in arg.promise.wait(): yield y
                    if arg.promise.value.failed:
                        log(2, "[" + str(netId(ctx)) + "] Whois for " + arg.promise.value.nick + " failed, skipping")
                    else:
                        log(1, "[" + str(netId(ctx)) + "] Received WHOIS: nick=" + arg.promise.value.nick + " ident=" + arg.promise.value.ident + " host=" + arg.promise.value.host + " account=" + (arg.promise.value.account or ""))
                        modeString.append(mode)
                        argString.append(arg.substitute(arg.promise.value))
                else:
                    modeString.append(mode)
                    if arg:
                        argString.append(arg)
            if len(modeString):
                sendCommand(ctx, "MODE " + a.channel + " " + "".join(modeString) + " " + " ".join(argString))
        else:
            raise a

def tryFixModes(version, action):
    ret = []
    listModes = version.get("listModes", "Ibe")
    alwaysArgModes = version.get("alwaysArgModes", "k")
    setArgModes = version.get("setArgModes", "l")
    neverArgModes = version.get("neverArgModes", "imnpst")
    statusModes = version.get("statusModes", "ov")
    lastArg = False
    for mode, arg in action.modes:
        if mode[1] in listModes:
            if not arg:
                lastArg = True
        elif mode[1] in alwaysArgModes:
            if not arg:
                lastArg = True
        elif mode[1] in setArgModes:
            if mode[0] == '+':
                if not arg:
                    log(2, "Ignoring mode " + mode + " without argument")
                    continue
            elif mode[0] == '-':
                if arg:
                    log(1, "Ignoring argument for " + mode)
                    arg = None
        elif mode[1] in neverArgModes:
            if arg:
                log(1, "Ignoring argument for " + mode)
                arg = None
        elif mode[1] in statusModes:
            if not arg:
                log(2, "Ignoring mode " + mode + " without argument")
                continue
        ma = ModeAction(channel = action.channel, modes = [(mode, arg)])
        if lastArg and arg != None:
            ret.append(ma)
            lastArg = False
        else:
            ModeAction.append(ret, ma)
    return ret

def command(w, we, u):
    cmd = w[0]
    channel = hexchat.get_info("channel")
    ctx = hexchat.get_context()
    @Async
    def async(thread):
        actions = parseActions(channel, we[1] if len(we) > 1 else "")
        log(0, "[" + str(netId(ctx)) + "] [" + channel + "] /" + cmd + " " + renderActions(actions))
        if cmd in ["cd", "d"]:
            ModeAction.append(actions, ModeAction(channel = channel, modes = [("-o", hexchat.get_info("nick"))]))
        whoises = {}
        if fixModes and not re.match(ignoreVersions, ctx.get_info("network")):
            version = versions.get(netId(ctx), {})
            newactions = []
            for a in actions:
                if isinstance(a, ModeAction):
                    newactions.extend(tryFixModes(version, a))
                else:
                    newactions.append(a)
            actions = newactions
        for a in actions:
            if isinstance(a, ModeAction):
                for mode, arg in a.modes:
                    if isinstance(arg, WhoisArg):
                        if arg.nick not in whoises:
                            whoises[arg.nick] = WhoisPromise(thread, ctx, arg.nick)
                        arg.promise = whoises[arg.nick]
        if cmd in ["cd", "co"]:
            c = ChanServPromise(thread, ctx, channel)
            for y in c.wait(): yield y
            if not c.value:
                log(2, "[" + str(netId(ctx)) + "] ChanServ OP failed, aborting actions in " + channel)
                return
            log(1, "[" + str(netId(ctx)) + "] Opped by ChanServ in " + channel + ", executing actions")
        for y in executeActions(ctx, actions): yield y
    return hexchat.EAT_ALL


hexchat.hook_server("311", WhoisPromise.handler311)
hexchat.hook_server("330", WhoisPromise.handler330)
hexchat.hook_server("318", WhoisPromise.handler318)
for numeric in ("276", "307", "310", "312", "313", "316", "317", "319", "320", "335", "337", "338", "378", "379", "671"):
    hexchat.hook_server(numeric, WhoisPromise.ignoreIfQueued)
hexchat.hook_server("MODE", ChanServPromise.handlerMODE)
hexchat.hook_server("NOTICE", ChanServPromise.handlerNOTICE)
hexchat.hook_server("005", handler005)

hexchat.hook_command("cd_log", commandLog);
hexchat.hook_command("cd_flush", commandFlush);
hexchat.hook_command("cd_status", commandStatus);
hexchat.hook_command("o", command);
hexchat.hook_command("d", command);
hexchat.hook_command("co", command);
hexchat.hook_command("cd", command);
