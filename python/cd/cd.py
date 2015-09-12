__module_name__ = "cd"
__module_author__ = "mniip"
__module_version__ = "0.0.3"
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

    Action syntax:
        An action is either a mode (plus or minus followed by a letter), or the
        letters 'k' and 'r' alone. If a different letter is encountered, it is
        assumed that a plus sign is missing.

        The 'k' action executes a kick. It is followed by a nickname and
        optionally a reason. A default reason can be configured below.

        The 'r' action executes a REMOVE (force-part). It is followed by a
        nickname and optinally a reason.

        Mode actions can be followed by a parameter, optionally prefixed by a
        WHOIS selector, and optionally suffixed by a redirection. A WHOIS
        selector runs a WHOIS query on the parameter (presumingly a nickname)
        and uses the resulting fields to construct a banmask. The selector is
        either the symbol ':', or a combination of '!', '~', and '@'. The ':'
        selector produces an account banmask: '$a:account'. Other selectors
        substitute respective fields into the '*!*@*' banmask. '@' replaces the
        host part of the banmask with the actual host provided by the WHOIS
        reply. Likewise, '~' substitutes ident, and '!' substitutes nickname.
        For example if you want to ban someone by nickname and host, you'd run
            /o +b !@ someone
        The redirection parameter corresponds to $#channel redirection bans, and
        consists of a dollar followed by a channel name.

        Multiple actions can be specified, using a semicolon-separated list.
        Moreover, multiple actions can use the same argument, for example the
        following simultaneously bans a user by host, and kicks them:
            /o +bk @ user Kick reason.
        The '+b' action ignores 'Kick reason', and the 'k' action ignores the
        '@' WHOIS selector.

        The syntax is whitespace-permissive, with the only exception being that
        when multiple actions reuse the same argument, they should be 'glued'
        into one word to avoid ambiguities. As such, the following commands are         the same:
            /o +bk@user$#redirect Reason;+q!user
            /o +bk @ user $ #redirect Reason ; +q ! user

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
modesPerLine = 4
logLevel = 1
logPrefixes = ["\x0302(==) ", "\x0303(**) ", "\x0304(EE) "]
logTab = "(cd)"
chanServFailure = r"not authorized|is not registered|is not on|is closed"

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

def sendCommand(command):
    log(0, "quote " + command)
    hexchat.command("quote " + command)

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
    def __init__(self, thread, nick):
            Promise.__init__(self, thread)
            self.nick = nick
            WhoisPromise.promises.append(self)
            sendCommand("WHOIS :" + self.nick)

    @staticmethod
    def propose(whois):
        def filt(p):
            if hexchat.nickcmp(p.nick, whois.nick) == 0:
                log(0, "Received WHOIS for " + p.nick)
                p.fulfill(whois)
                return False
            else:
                return True
        WhoisPromise.promises = filter(filt, WhoisPromise.promises)

    lastWhois = None

    @staticmethod
    def handler311(w, we, u):
        WhoisPromise.lastWhois = Whois(nick = w[3], ident = w[4], host = w[5], account = None, failed = False)

    @staticmethod
    def handler330(w, we, u):
        WhoisPromise.lastWhois.account = w[4]

    @staticmethod
    def handler318(w, we, u):
        if WhoisPromise.lastWhois == None:
            WhoisPromise.propose(Whois(nick = w[3], failed = True))
        else:
            WhoisPromise.propose(WhoisPromise.lastWhois)
        WhoisPromise.lastWhois = None

class ChanServPromise(Promise):
    promises = []
    def __init__(self, thread, channel):
            Promise.__init__(self, thread)
            self.channel = channel
            ChanServPromise.promises.append(self)
            sendCommand("PRIVMSG ChanServ :OP " + self.channel)

    @staticmethod
    def handlerMODE(w, we, u):
        source = w[0][1:].split("!", 1)[0]
        if source == "ChanServ":
            mode = w[3]
            nick = w[4]
            if mode == "+o" and hexchat.nickcmp(nick, hexchat.get_info("nick")) == 0:
                channel = w[2]
                def filt(p):
                    if hexchat.nickcmp(p.channel, channel) == 0:
                        p.fulfill(True)
                        return False
                    else:
                        return True
                ChanServPromise.promises = filter(filt, ChanServPromise.promises)

    @staticmethod
    def handlerNOTICE(w, we, u):
        source = w[0][1:].split("!", 1)[0]
        text = we[3]
        if source == "ChanServ" and re.search(chanServFailure, text):
            for p in ChanServPromise.promises:
                p.fulfill(False)
            ChanServPromise.promises = []

def commandFlush(w, we, u):
    WhoisPromise.promises = []
    ChanServPromise.promises = []
    log(1, "Flushed ChanServ and WHOIS threads")
    return hexchat.EAT_ALL

def commandStatus(w, we, u):
    for p in ChanServPromise.promises:
        hexchat.prnt("Waiting for ChanServ in " + p.channel)
    for p in WhoisPromise.promises:
        hexchat.prnt("Waiting for WHOIS reply for " + p.nick)
    return hexchat.EAT_ALL

class Action(Struct): pass
class KickAction(Action): pass
class RemoveAction(Action): pass

class ModeAction(Action):
    @staticmethod
    def append(list, mode):
        if len(list):
            a = list[-1]
            if isinstance(a, ModeAction) and a.channel == mode.channel and len(a.modes) < modesPerLine:
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
        nick, rest = re.match(r"^(\$*[^\s$]*)(.*)$", rest).groups()
        rest = rest.lstrip()
        forward = None
        m = re.match(r"^\$\s*(\S+)(.*)$", rest)
        if m:
            forward, rest = m.groups()
        extra = rest.lstrip()
        for command in re.findall(r"[+-=]?[a-zA-Z]", commands):
            if command == "k":
                actions.append(KickAction(channel = channel, nick = nick, reason = extra))
            elif command == "r":
                actions.append(RemoveAction(channel = channel, nick = nick, reason = extra))
            else:
                if command[0] not in ["+", "-", "="]:
                    command = "+" + command
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
        elif isinstance(a, RemoveAction):
            ret.append("r " + a.nick + (" " + a.reason if a.reason else ""))
        elif isinstance(a, ModeAction):
            for mode, arg in a.modes:
                if isinstance(arg, WhoisArg):
                    ret.append(mode + " " + arg.whoiser + " " + arg.nick + (" $ " + arg.forward if arg.forward else ""))
                else:
                    ret.append(mode + (" " + arg if arg else ""))
    return " ; ".join(ret)


def executeActions(actions):
    for a in actions:
        if isinstance(a, KickAction):
            sendCommand("KICK " + a.channel + " " + a.nick + " :" + (a.reason or defaultKickReason))
        elif isinstance(a, RemoveAction):
            sendCommand("REMOVE " + a.channel + " " + a.nick + (" :" + a.reason if a.reason else ""))
        elif isinstance(a, ModeAction):
            modeString = []
            argString = []
            for mode, arg in a.modes:
                if isinstance(arg, WhoisArg):
                    for y in arg.promise.wait(): yield y
                    if arg.promise.value.failed:
                        log(2, "Whois for " + arg.promise.value.nick + " failed, skipping")
                    else:
                        log(1, "Received WHOIS: nick=" + arg.promise.value.nick + " ident=" + arg.promise.value.ident + " host=" + arg.promise.value.host + " account=" + (arg.promise.value.account or ""))
                        modeString.append(mode)
                        argString.append(arg.substitute(arg.promise.value))
                else:
                    modeString.append(mode)
                    if arg:
                        argString.append(arg)
            sendCommand("MODE " + a.channel + " " + "".join(modeString) + " " + " ".join(argString))
        else:
            raise a

def command(w, we, u):
    cmd = w[0]
    channel = hexchat.get_info("channel")
    @Async
    def async(thread):
        actions = parseActions(channel, we[1] if len(we) > 1 else "")
        log(0, "[" + channel + "] /" + cmd + " " + renderActions(actions))
        if cmd in ["cd", "d"]:
            ModeAction.append(actions, ModeAction(channel = channel, modes = [("-o", hexchat.get_info("nick"))]))
        whoises = {}
        for a in actions:
            if isinstance(a, ModeAction):
                for mode, arg in a.modes:
                    if isinstance(arg, WhoisArg):
                        if arg.nick not in whoises:
                            whoises[arg.nick] = WhoisPromise(thread, arg.nick)
                        arg.promise = whoises[arg.nick]
        if cmd in ["cd", "co"]:
            c = ChanServPromise(thread, channel)
            for y in c.wait(): yield y
            if not c.value:
                log(2, "ChanServ OP failed, aborting actions in " + channel)
                return
            log(1, "Opped by ChanServ in " + channel + ", executing actions")
        for y in executeActions(actions): yield y
    return hexchat.EAT_ALL


hexchat.hook_server("311", WhoisPromise.handler311)
hexchat.hook_server("330", WhoisPromise.handler330)
hexchat.hook_server("318", WhoisPromise.handler318)
hexchat.hook_server("MODE", ChanServPromise.handlerMODE)
hexchat.hook_server("NOTICE", ChanServPromise.handlerNOTICE)

hexchat.hook_command("cd_log", commandLog);
hexchat.hook_command("cd_flush", commandFlush);
hexchat.hook_command("cd_status", commandStatus);
hexchat.hook_command("o", command);
hexchat.hook_command("d", command);
hexchat.hook_command("co", command);
hexchat.hook_command("cd", command);
