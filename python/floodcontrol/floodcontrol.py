from __future__ import print_function, unicode_literals

import hexchat
import random
import threading
import time
import itertools
import re
import argparse
import traceback
from collections import defaultdict
from functools import wraps

import sys, os
sys.path.append(os.path.join(os.path.dirname(__file__), "submodules"))

# helper modules that should've come with this one. Place them in "submodules" directory, in the same directory as this script.
import inputbox as ibx
import pastebins

# dependency: xerox, for handling clipboards.
try:
    import xerox
    HAVE_XEROX = True
except ImportError:
    print("\002[Floodcontrol]\017\t", "xerox not found, we won't be able to use clipboards. https://pypi.python.org/pypi/xerox https://github.com/kennethreitz/xerox")
    HAVE_XEROX = False

__module_name__ = str("Floodcontrol") # Alternative names: Discharge, Flood Tunnel, Storm Drain.
__module_version__ = str("0.1")
__module_description__ = str("Sends your floody messages to a pastebin service and gives you the URL.")

"""HexChat plugin for intercepting floody messages from the user, and redirecting them to a pastebin service."""

# IDEA: User could set their own shell command for us to use, we'll send the contents to its stdin.

def get_max_lines():
    # TODO: Should be more for PMs, and less for large channels.
    # TODO: These defaults could be overridden by users, per channel/window.
    return 2

KEYS = {"enter":        ['65293', '0', '\r', '1'],
        "ctrl+enter":   ['65293', '4', '\r', '1'],
        "altgr+enter":  ['65293', '128', '\r', '1'],
        "alt+enter":    ['65293', '8', '\r', '1'],
        "space":        ['32', '0', ' ', '1'],
        "tab":          ['65289', '0', '', '0']
        }

# TODO
# Possible additional options & examples:
# pastebin: pastebin.com, dpaste.de, codepad, random
# expiry: 1 day, 1 week, shortest, longest, infinite (we'd pick the closest possible)
# name
#

DEBUG = False

def print_fc(*args, **kwargs):
    return print("\002[Floodcontrol]\017\t", *args, **kwargs)

def print_debug(*args, **kwargs):
    if DEBUG:
        return print("\002[FC_debug]\017\t", *args, **kwargs)

def is_mainthread():
    try:
        return threading.main_thread() is threading.current_thread()
    except AttributeError: # < py3.4
        return isinstance(threading.current_thread(), threading._MainThread)

def default_returnvalue(returnvalue, error_returnvalue):
    # Decorator for always returning a default value if None is returned by the
    # decorated function, or if the decorated function raises an error.
    #
    # This is to prevent HexChat behaviour where if a command raises an exception,
    # the event isn't eaten. We use this to EAT_HEXCHAT by default.
    def dec(f):
        @wraps(f)
        def wrapped(*args, **kwargs):
            try:
                r = f(*args, **kwargs)
            except Exception as e:
                for line in traceback.format_exception():
                    print_fc(line.strip())
                return error_returnvalue

            if r is None:
                return returnvalue
            else:
                return r
        return wrapped
    return dec

class FloodcontrolError(BaseException):
    pass

class PluginConfigError(FloodcontrolError):
    pass

class ArgparseException(FloodcontrolError):
    pass

class ArgparseError(ArgparseException):
    pass

class ArgparseExit(ArgparseError):
    pass

class NoExitParser(argparse.ArgumentParser):
    raise_on_next_fail = False # TODO: override __init__ and put this in there
    def exit(self, *args, **kwargs):
        if self.raise_on_next_fail:
            self.raise_on_next_fail = False
            raise ArgparseExit(args, kwargs)
        else:
            print_debug("(ArgparseExit)", args, kwargs)
    def error(self, *args, **kwargs):
        if self.raise_on_next_fail:
            self.raise_on_next_fail = False
            raise ArgparseError(args, kwargs)
        else:
            print_debug("(ArgparseError)", args, kwargs)

##################
##################

######## Configuration


default_config = {
    "service": "pb",
    "expiry": "1 week",
    "exposure": "unlisted",
    "syntax": "text",
    "name": "Auto-pasted by Hexchat Floodcontrol"
}

def make_argparser_and_args_after_config():
    global argparser, ARG_GROUPS, ALL_ARGS
    argparser, ARG_GROUPS, ALL_ARGS = make_argparser_and_args()

def set_option(key, value):
    hkey = "{}_{}".format(__module_name__, key)

    success = hexchat.set_pluginpref(hkey, value)
    if not success:
        raise PluginConfigError((key, value))
    make_argparser_and_args_after_config()

def get_option(key):
    default = default_config.get(key)
    if default is not None:
        return default
    else:
        hkey = "{}_{}".format(__module_name__, key)

        return hexchat.get_pluginpref(hkey)

def del_option(key):
    hkey = "{}_{}".format(__module_name__, key)

    success = hexchat.del_pluginpref(hkey)
    if not success:
        raise PluginConfigError(key)
    make_argparser_and_args_after_config()

def set_max_lines_for_channel(value=None, channel=None, network=None):
    # TODO: This and the next function are supposed to set the preferred maximum
    # lines before we should ask the user whether to pastebin.
    if channel is None:
        channel = hexchat.get_info("channel")
    if network is None:
        network = hexchat.get_info("network")
    key = "maxlines_{}_{}".format(channel, network)

    if value is not None:
        set_option(key, value)
    else:
        del_option(key)

def get_max_lines_for_channel(channel=None, network=None):
    key = "maxlines_{}_{}".format(channel, network)
    # TODO

###

# TODO: Have a single "set_option_cmd" function, with validator functions for each valid option.

@default_returnvalue(hexchat.EAT_HEXCHAT, hexchat.EAT_ALL)
def set_service_cmd(words, words_eol, *args):
    apis = pastebins.get_api_names()
    default_api = default_config.get('service')
    available_str = "Available pastebins (or 'default' for {}): {}".format(default_api, apis)
    if len(words) == 1:
        print_fc(available_str)
        print_fc("Current pastebin: {}".format(get_option("service")))
    else:
        if words[1] in apis:
            set_option("service", words[1])
        elif words[1] == "default":
            del_option("service")
        else:
            print_fc("We don't have that pastebin. {}".format(available_str))
            return
        print_fc("Pastebin is now: {}".format(get_option("service")))

# TODO: test this.
@default_returnvalue(hexchat.EAT_HEXCHAT, hexchat.EAT_ALL)
def set_option_cmd(words, words_eol, userdata, *args):
    option_name = userdata
    try:
        option_value = words[1]
    except IndexError:
        option_value = None

    option_setters = {"service": set_service_cmd}
    # We don't validate the following because different APIs might handle them [in]correctly.
    # TODO: add validators to the PastebinAPI objects?
    option_rest = {"expiry", "exposure", "syntax", "name"}
    if option_name in option_rest.union(option_funcs):
        if callable(option_funcs.get(option_name)):
            return option_funcs[option_name](words, words_eol)
        else:
            if option_value is None:
                print_fc("Current {} setting: {}".format(option_name, get_option(option_name)))
            else:
                if option_value == "default":
                    del_option(option_name)
                else:
                    set_option(option_name, option_value)
                print_fc("{} setting is now: {}".format(option_name, get_option(option_name)))


# Passed to the `pastebins` submodule for use in HTTP requests:
USER_AGENT = "hexchat-{}/{}".format(__module_name__, __module_version__)

def _pastebin(contents, **kwargs):
    pastebin = pastebins.get_api_by_name(kwargs['service'])
    print_fc("Sending paste to {}...".format(kwargs['service']))
    start_time = time.time()
    result = pastebin.write(contents, **kwargs)
    if result[1] is not None:
        print_fc("Response from {}:".format(kwargs['service']))
        print_fc(result[1])
        print_fc("Time taken: {}".format(time.time() - start_time))
    return result[0]

def pastebin(callback, contents, **kwargs):
    for argname in ARG_GROUPS['api']:
        if argname not in kwargs:
            kwargs[argname] = get_option(argname)

    callback(_pastebin(contents, **kwargs))

def pastebin_thread(callback, *args, **kwargs):
    print_debug("pastebin_thread", callback, args, kwargs)
    thread = threading.Thread(target=pastebin, args=(callback,)+args, kwargs=kwargs)
    thread.start()
    return thread

@default_returnvalue(hexchat.EAT_HEXCHAT, hexchat.EAT_ALL)
def add_shellcommand_pastebin_cmd(words, words_eol, *args):
    # TODO: Write to config in order to make the setting permanent.
    words = words + ([None] * (4 - len(words)))
    apiname, shellcommand, shellcommand_read = words[1:4]

    pastebins.add_shellcommand_pastebin(apiname, shellcommand, shellcommand_read)

    print_fc("Shell command Pastebin API added. Name: {}, Command to write: {}, Command to read: {}".format(apiname, shellcommand, shellcommand_read))

@default_returnvalue(hexchat.EAT_HEXCHAT, hexchat.EAT_ALL)
def remove_shellcommand_pastebin_cmd(words, words_eol, *args):
    apiname = words[1]
    api = pastebins.get_api_by_name(apiname)
    if isinstance(api, pastebins.ShellCommandPastebin):
        api.remove_api()
    else:
        raise FloodControlError("{} is not a ShellCommandPastebin, cannot remove.".format(apiname))
    print_fc("Shell command Pastebin API added. Name: {}".format(apiname))

# TODO: A context manager or decorator which always returns hexchat.EAT_HEXCHAT even when an exception is raised.

# The following two functions are based on split_up_text in hexchat/src/common/outbound.c.
def split_up_text(text, maxlen, cmd_length):
    if len(text) > maxlen:
        # Try splitting at last space:
        spaceindex = text.rfind(" ", 0, maxlen)
        if spaceindex >= 0:
            # Only split if last word is of sane length:
            if maxlen != spaceindex and maxlen - spaceindex < 20:
                maxlen = spaceindex + 1

        split_text = text[:maxlen]

        return split_text

# This and the previous function is based on split_up_text in hexchat/src/common/outbound.c.
def splits_up_text(text, cmd_length):
    maxlen = 512 # rfc 2812
    maxlen -= 3 # :, !, @
    maxlen -= cmd_length
    maxlen -= len(hexchat.get_info("nick"))
    maxlen -= len(hexchat.get_info("channel"))

    # Hexchat's Python interface doesn't provide for a nice way to get our own
    # username and hostname. Writing a hack to do it isn't worth it for this case.
    maxlen -= 9 + 65 # max length of username@hostname

    l = 0
    splits = []
    while True:
        split_text = split_up_text(text[l:], maxlen, cmd_length)
        if split_text is None:
            splits.append(text[l:])
            break
        l += len(split_text)
        splits.append(split_text)
    return splits

def linecount(message=None, cmd_length=len(" PRIVMSG : \r\n")):
    if message is None:
        message = hexchat.get_info("inputbox")

    split_msg = message.splitlines()

    approximate = False
    linecount = 0
    for line in split_msg:
        lines_in_line = len(splits_up_text(line, cmd_length))
        if lines_in_line > 1:
            approximate = True
        linecount += lines_in_line

    return linecount, approximate

commands_options = { # Values may be dicts or callables which return dicts when called with inputbox text.
    "msg": {
        "cmdlength": len(" PRIVMSG : \r\n"),
        "paramcount": 1
        },
    "notice": {
        "cmdlength": len(" NOTICE : \r\n"),
        "paramcount": 1
        },
    "me": {
        "cmdlength": len(" PRIVMSG : \001ACTION \001\r\n"),
        "paramcount": 0
        }
}

commands_options['say'] = {"cmdlength": commands_options['msg']['cmdlength'], 'paramcount': 0}
commands_options['m'] = commands_options['msg']

def add_special_preprocessors():
    # For when a command's paramcount depends on what the command's parameters
    # are, or something dynamic like that.
    # Special preprocessors should never return another callable. Instead, they
    # could use get_opts_for_cmd which would do the recursion.
    def get_opts_for_wrappercmd(inputbox):
        # for wrapper commands like /allchan, /allchanl, and /allserv
        msg_split = inputbox.split(" ")
        command = msg_split[1]
        options = get_opts_for_cmd(command, inputbox).copy()
        if 'paramcount' in options:
            options['paramcount'] += 1
        return options
    for command in ['allchan', 'allchanl', 'allserv', 'doat']:
        commands_options[command] = get_opts_for_wrappercmd

add_special_preprocessors()

def get_opts_for_cmd(command, inputbox):
    print_debug("get_opts_for_cmd", command, inputbox, sep="|")
    options = commands_options.get(command.lower())
    if callable(options):
        options = options(inputbox)
    return options

######## Argument parsing and input/output for /fc_paste command and do_paste function

def find_content_in_args(words, words_eol, parser, key_to_watch="content"):
    # Works around argparse's magic to find the raw unparsed content to pastebin.
    # The alternative was to create an ArgumentParser sublcass and then override
    # or wrap a _semiprivate method. This would have been bad because the
    # _semiprivately named methods are unspecified and might change, per convention.

    # The problem this solves can be demonstrated in the example:
    # /argparse --validflag -v2 content to paste goes -- here
    # Would normally output: "content to paste goes here", where we would want
    # "content to paste goes -- here", also parsing out any quoted statements
    # which we needed to have raw.

    # TODO: binary search might be faster
    command_params = words[1:]
    parsed_before = []
    for i in range(len(command_params)):
        to_parse = command_params[:i+1]
        try:
            parser.raise_on_next_fail = True
            parsed, extra = parser.parse_known_args(to_parse)
            parser.raise_on_next_fail = False
        except ArgparseException as e:
            print_debug("e", repr(e))
            continue
        parsed = vars(parsed)
        print_debug("e_parsed", parsed)
        print_debug("extra", extra)

        if len(parsed[key_to_watch]) > 0 or len(extra) > 0:
            if len(parsed_before) == 0:
                if i > 0:
                    return None, words_eol[i+1]
                else:
                    return parsed, words_eol[i+1]
            else:
                return parsed_before[-1], words_eol[i+1]

        parsed_before.append(parsed)

    print_debug("parsed_before", parsed_before)
    # No extras found.
    return parsed_before[-1], None

def output_from_argparse(output, parsed_args): # TODO: argparse functions need better name.
    parsed_args = parsed_args.copy()

    commands = parsed_args.get('to_command')
    if commands is None:
        commands = []

    if parsed_args.get('say'):
        commands.append("say")

    for c in commands:
        hexchat.command(" ".join((c, output)))
    if parsed_args.get('guard_inputbox_cmd') and (parsed_args.get('to_inputbox') or parsed_args.get('to_inputbox_replace')):
        ibx.set(" ".join((parsed_args['guard_inputbox_cmd'][0], output)))
    elif parsed_args.get("to_inputbox"):
        ibx.add_at_cursor(output)
    elif parsed_args.get("to_inputbox_replace"):
        ibx.set(output)
    if parsed_args.get("to_clipboard") and HAVE_XEROX:
        xerox.copy(output)


def get_input_from_argparse(callback, parsed_args):
    print_debug(parsed_args)
    parsed_args = parsed_args.copy()
    source = parsed_args.get('source')
    print_debug("get_input args", parsed_args)

    if parsed_args.get("confirm"):
        del parsed_args['confirm']
        def confirmed_cb(b):
            if b:
                get_input_from_argparse(callback, parsed_args)
        if is_mainthread():
            send_getbool_to_callback(confirmed_cb)
        else:
            hexchat.hook_timer(20, send_getbool_to_callback, confirmed_cb)
        return

    if source == "inputbox":
        if not parsed_args['guard_inputbox_cmd']:
            callback(ibx.get())
        else:
            callback(parsed_args['guard_inputbox_cmd'][1])

    elif source == "clipboard" and HAVE_XEROX:
        callback(xerox.paste())

    elif source == "window":
        # Ask main thread to getstr and then give it to our callback.
        if is_mainthread():
            send_getstr_to_callback(callback)
        else:
            hexchat.hook_timer(20, send_getstr_to_callback, callback)

    else:
        raise FloodcontrolError("Could not get input. Requested source: {}".format(source))

hexchat_callback_handlers = defaultdict(list)

def send_getstr_to_callback(callback):
    # TODO: More generalised callback-command thing?
    cmdname = ".floodcontrol_cb_getstr"
    @default_returnvalue(hexchat.EAT_HEXCHAT, hexchat.EAT_ALL)
    def callback_and_unhook(words, words_eol, *args):
        o = words_eol[1]
        if o != "(paste here)":
            threading.Thread(target=callback, args=(o,)).start()
        {hexchat.unhook(handler) for handler in hexchat_callback_handlers[cmdname]}
    {hexchat.unhook(handler) for handler in hexchat_callback_handlers[cmdname]}
    handler = hexchat.hook_command(cmdname, callback_and_unhook, userdata=time.time())
    hexchat_callback_handlers[cmdname].append(handler)
    hexchat.command(" ".join(("GETSTR", '"(paste here)"', cmdname, '"Floodcontrol pastebin input:"')))

def send_getbool_to_callback(callback):
    # TODO: More generalised callback-command thing?
    cmdname = ".floodcontrol_cb_getbool"
    @default_returnvalue(hexchat.EAT_HEXCHAT, hexchat.EAT_ALL)
    def callback_and_unhook(words, words_eol, *args):
        o = bool(int(words_eol[1]))
        threading.Thread(target=callback, args=(o,)).start()
        {hexchat.unhook(handler) for handler in hexchat_callback_handlers[cmdname]}
    {hexchat.unhook(handler) for handler in hexchat_callback_handlers[cmdname]}
    handler = hexchat.hook_command(cmdname, callback_and_unhook, userdata=time.time())
    hexchat_callback_handlers[cmdname].append(handler)
    hexchat.command(" ".join(("GETBOOL", cmdname, '"Floodcontrol"', '"Confirm sending to pastebin?"')))

argparser = ARG_GROUPS = ALL_ARGS = None
def make_argparser_and_args():
    argparser = NoExitParser("fc_paste") # TODO: find way for this name to be set dynamically by the command running it.

    help_xerox_missing = "Does nothing apart from telling the user about the missing 'xerox' dependency. Would do something if we had the 'xerox' dependency."

    inputgroup = argparser.add_argument_group(title="Input sources")
    ia = []
    ia.append(inputgroup.add_argument("content", nargs="*", help="Ignored if a --from-* argument is specified. The content we should send to the pastebin. Not reliable when running the command from HexChat's inputbox because of how line breaks behave. Use a --from-* argument instead."))
    ia.append(inputgroup.add_argument("-fi", "--from-inputbox", action="store_const", help="If specified, will retrieve HexChat inputbox contents and send it to the pastebin.", dest="source", const="inputbox"))
    if HAVE_XEROX:
        ia.append(inputgroup.add_argument("-fb", "--from-clipboard", action="store_const", help="If specified, will retrieve clipboard and send it to the pastebin.", dest="source", const="clipboard"))
    else:
        ia.append(inputgroup.add_argument("-fb", "--from-clipboard", action="store_true", help=help_xerox_missing, dest="tried_clipboard"))
    ia.append(inputgroup.add_argument("-fw", "--from-window", action="store_const", help="If specified, will create a popup window using /GETSTR and send the response to the pastebin.", dest="source", const="window"))
    ia.append(inputgroup.add_argument("-C", "--confirm", action="store_true", help="If specified, we will first use /GETBOOL to get user confirmation before sending data to the patebin service."))

    # Pastebin API options. The interpretation and functionality of these depend completely on the chosen API.
    # TODO: Custom HelpFormatter for bold and italics in IRC.

    bin_api_group = argparser.add_argument_group(title="Pastebin API arguments")
    ba = []
    ba.append(bin_api_group.add_argument("-p", "--service", default=get_option("service"), help="The name of the pastebin API desired."))
    ba.append(bin_api_group.add_argument("-n", "--name", default=get_option("name"), help="The name of your paste."))
    ba.append(bin_api_group.add_argument("-e", "--expiry", default=get_option("expiry"), help="Length of time we should tell the pastebin API to keep the paste."))
    ba.append(bin_api_group.add_argument("-s", "--syntax", default=get_option("syntax"), help="Try to get the pastebin to use syntax highlighting, e.g. 'python' or 'html'"))
    ba.append(bin_api_group.add_argument("-x", "--exposure", default=get_option("exposure"), help="Privacy setting for this paste."))
    
    # TODO: Make this work:
    #ba.append(bin_api_group.add_argument("-c", "--custom-opt", action="append", help="Custom options to give to the Pastebin API (as strings). For instance, some APIs might be coded to support a maximum read count. Use the syntax \"key=value\" including quotes."))

    outputgroup = argparser.add_argument_group(title="Output destinations")
    oa = []
    oa.append(outputgroup.add_argument("-tc", "--to-command", action="append", metavar="COMMAND", help="The command that should be ran with the result, e.g. '--to-command \"/msg OtherPerson\" content goes here' will send the Pastebin URL as '/msg OtherPerson http://example.com/abcd'."))
    oa.append(outputgroup.add_argument("-ti", "--to-inputbox", action="store_true", help="If specified, will add the pastebin URL to HexChat's inputbox at the current cursor position."))
    oa.append(outputgroup.add_argument("-tir", "--to-inputbox-replace", action="store_true", help="If specified, will set HexChat's inputbox to the pastebin URL."))
    if HAVE_XEROX:
        oa.append(outputgroup.add_argument("-tb", "--to-clipboard", action="store_true", help="If specified, will add the pastebin URL to the clipboard."))
    else:
        oa.append(outputgroup.add_argument("-tb", "--to-clipboard", action="store_true", help=help_xerox_missing, dest="tried_clipboard"))
    oa.append(outputgroup.add_argument("-S", "--say", action="store_true", help="If specified, will output pastebin URL to current window. Same as '--to-command say'"))

    ma = []
    # The following arg gets mutated into a tuple, when used through do_paste_cmd: (command, rest_of_message)
    ma.append(argparser.add_argument("--guard-inputbox-cmd", action="store_true", help="If specified, will take care not to send known commands to the pastebin, and preserve it when we get the URL back. For instance, \"/msg Burrito testing\" would only send \"testing\" and preserve \"/msg Burrito\" in the inputbox."))

    ARG_GROUPS = {}
    ARG_GROUPS['input'] = {arg.dest for arg in ia}
    ARG_GROUPS['api'] = {arg.dest for arg in ba}
    ARG_GROUPS['output'] = {arg.dest for arg in oa}
    ARG_GROUPS['misc'] = {arg.dest for arg in ma}
    ALL_ARGS = set(itertools.chain(*ARG_GROUPS.values()))

    return argparser, ARG_GROUPS, ALL_ARGS
argparser, ARG_GROUPS, ALL_ARGS = make_argparser_and_args()

@default_returnvalue(hexchat.EAT_HEXCHAT, hexchat.EAT_ALL)
def do_paste_cmd(words, words_eol, userdata, *args, **kwargs):
    # IDEA/TODO: Paster object to store options and argparser?
    # Example:
    # /fc_paste -fb -n "Paste name" -p pb -e "1 week" -s text -x unlisted -S
    # /fc_paste -tc "command" Paste content goes here
    # /fc_paste -fb -ti -C
    # /fc_paste -h

    parsed_args = kwargs.get("parsed_args")

    print_debug("words", words)
    for w in words_eol:
        print_debug("words_eol:", w)
    if parsed_args is None:
        parsed_args, content = find_content_in_args(words, words_eol, argparser)
        parsed_args['content'] = content
    if parsed_args['guard_inputbox_cmd'] and parsed_args['source'] == "inputbox":
        # TODO: could split into separate function and also use in do_paste
        doprocess, message, fullcommand, _ = preprocess_inputbox(ibx.get())
        if doprocess:
            parsed_args['guard_inputbox_cmd'] = fullcommand, message
        else:
            parsed_args['guard_inputbox_cmd'] = False
    print_debug("parsed", parsed_args)


    do_paste(**parsed_args)

def add_config_to_options(options, keys=ALL_ARGS, filter_keys=None):
    # TODO: take a look at dict.get and dict.setdefault, we might be able to use it here
    if filter_keys is not None:
        options = {k: v for k, v in options.items() if k in filter_keys}
    else:
        options = options.copy()

    for arg in keys:
        if arg not in options:
            options[arg] = get_option(arg)
    return options


def do_paste(**options): # unknown options are discarded, see PASTECMD_ARGS
    print_debug("ALL_ARGS", ALL_ARGS)
    options = {k: v for k, v in options.items() if k in ALL_ARGS}
    api_options = add_config_to_options(options, ARG_GROUPS['api'], ARG_GROUPS['api'])
    if options.get('tried_clipboard'):
        print_fc("We cannot use the clipboard, because we do not have the 'xerox' dependency. https://pypi.python.org/pypi/xerox https://github.com/kennethreitz/xerox")
    def paste_content_cb(content):
        # Receives paste content, sends it to the pastebin. Pastebin API will reply through url_cb.
        pastebin_thread(url_cb, content, **api_options)
    def url_cb(url):
        # Takes in pastebin URL, outputs URL to necessary places.
        output_from_argparse(url, options)
    thread = threading.Thread(target=get_input_from_argparse, args=(paste_content_cb, options))
    thread.start()
    return thread

@default_returnvalue(hexchat.EAT_HEXCHAT, hexchat.EAT_ALL)
def inputbox_autopaste_on_limit(*args):
    if len(args) < 4:
        doprocess, message, fullcommand, cmd_length = preprocess_inputbox(ibx.get())
    else:
        doprocess, message, fullcommand, cmd_length = args
    options = {"guard_inputbox_cmd": (fullcommand, message),
               "source": "inputbox",
               "to_inputbox": True}
    do_paste(**options)

re_words = re.compile(r"(\S*\s)")

def preprocess_inputbox(inputbox):
    # Return values:
    # doprocess, message, fullcommand, cmd_length
    # TODO: only return at end.
    # "doprocess" means we can understand what needs to be parsed in the inputbox so that we can have content to pastebin.
    # "message" is the content to pastebin, without the command.
    # "fullcommand" is the command we have parsed from the inputbox.
    #   e.g. "/msg OtherUser"
    # "cmd_legth" is how much space this command would take up in the raw message to the server.
    cmdprefix = hexchat.get_prefs("input_command_char") # default is "/" as in "/msg"
    if not inputbox.startswith(cmdprefix):
        cmd_length = commands_options['say']['cmdlength']
        return True, inputbox, "", cmd_length
    else:
        boxsplit = [word for word in re.split(re_words, inputbox) if word]
        print_debug("boxsplit", boxsplit)
        command = boxsplit[0]
        command = command.lstrip("/").rstrip()
        options = get_opts_for_cmd(command, inputbox)
        if options is not None:
            paramcount = options['paramcount']
            re_cmd_and_msg = r"((?:\S*\s){%s})" % paramcount

            # fullcommand here would be "/msg OtherUser" in the example of "/msg OtherUser message"
            # TODO: /msg otheruser longmsg doesn't work
            _, fullcommand, message = [word for word in re.split(re_cmd_and_msg, inputbox) if word]
            fullcommand.strip()

            cmd_length = options['cmdlength']
            return True, message, fullcommand, cmd_length
    return False, None, None, None


######## Callbacks and hooks

# IDEA: User types: "blah blah blah %Po%longtextgoeshere%Pc% blah blah"
#  And it gets turned into: "blah blah blah http://e.g.bin/jdkfai blah blah"
# Alternatively, user could enter a keyboard shortcut and we insert a placeholder for them.
# Like a Unicode non-character character.

_mode = 0
def mode(*args):
    global _mode
    if len(args) > 0:
        print_debug("mode", _mode, "to", args[0])
        _mode = args[0]
    return _mode


def keypress_cb(key, *args):
    # TODO: Split into functions. State information should be held as object attributes?

    #try:
    inputbox = hexchat.get_info("inputbox")

    if key == KEYS["enter"] and len(inputbox) > 0:
        doprocess, message, fullcommand, cmd_length = preprocess_inputbox(inputbox)
        if message is not None:
            print_debug(doprocess, len(message), message[:50], fullcommand, sep="|")
        else:
            print_debug(doprocess, message, fullcommand, sep="|")
        if doprocess:
            # "doprocess" here means that we can understand what we need to
            # extract from the inputbox, and how to send the replacement.
            nlines, approx = linecount(message, cmd_length)
            nprefix = "~" * approx

            if mode() == 0 and nlines > get_max_lines():
                print_fc("That message looks like a flood ({}{} lines). To really send it, "
                "press \002Alt+Enter\017. To send it through a pastebin, "
                "press \002Enter\017 again.".format(nprefix, nlines))
                mode(1)
                return hexchat.EAT_ALL
            elif mode() == 1 and nlines > get_max_lines():
                mode(0)
                return inputbox_autopaste_on_limit(doprocess, message, fullcommand, cmd_length)
            elif not nlines > get_max_lines():
                mode(0)
                return hexchat.EAT_NONE


    elif key in (KEYS["alt+enter"], KEYS["altgr+enter"]) or key[-1] != '0':
        mode(0)

    if key in (KEYS["enter"], KEYS["tab"]) and len(inputbox) > 8:
        pass

def debug_keypress_cb(key, *args):
    print_debug(key)

debug_handler = None
@default_returnvalue(hexchat.EAT_HEXCHAT, hexchat.EAT_ALL)
def toggle_debug(*args):
    global debug_handler
    global DEBUG

    if not debug_handler:
        print_fc("enabling debug")
        DEBUG = True
        debug_handler = hexchat.hook_print("Key Press", debug_keypress_cb)
    else:
        print_fc("disabling debug")
        DEBUG = False
        hexchat.unhook(debug_handler)
        debug_handler = None

autopaste_handler = None
@default_returnvalue(hexchat.EAT_HEXCHAT, hexchat.EAT_ALL)
def toggle_autopaste(*args):
    global autopaste_handler
    words = args[0]
    bools = {True: ("1", "on", "true", "t"), False: ("0", "off", "false", "f")}
    try:
        requested = words[1]
    except IndexError: # oh god
        requested = ""

# TODO
# /fc_autopaste off
# 074 [21:02:11] [Floodcontrol]  disabling autopaste
# /fc_autopaste off
# 074 [21:02:15]  Traceback (most recent call last):
# 074 [21:02:15]    File "/home/user/.config/hexchat/addons_wip/floodcontrol/floodcontrol.py", line 801, in toggle_autopaste
# 074 [21:02:15]      if requested.lower() in v:
# 074 [21:02:15]  SystemError: ../Objects/longobject.c:426: bad argument to internal function
    print_debug(requested)
    if not autopaste_handler and requested.lower() not in bools[False]:
        print_fc("enabling autopaste")
        autopaste_handler = hexchat.hook_print("Key Press", keypress_cb)
    elif requested.lower() not in bools[True]:
        print_fc("disabling autopaste")
        hexchat.unhook(autopaste_handler)
        autopaste_handler = None

if __name__ == "__main__":

    hexchat.hook_command("fc_debug", toggle_debug)

    hexchat.hook_command("fc_autopaste", toggle_autopaste)
    toggle_autopaste(["", "on"])
    hexchat.hook_command("fc_setpastebin", set_service_cmd, help="Set which pastebin to use for Floodcontrol. Provide no parameters to see a list of available pastebins. Provide 'default' to set back to default.")

    hexchat.hook_command("fc_paste", do_paste_cmd, help="Try /fc_paste -h")

    hexchat.hook_command("fc_rm_shellpastebin", remove_shellcommand_pastebin_cmd)
    hexchat.hook_command("fc_add_shellpastebin", add_shellcommand_pastebin_cmd) # TODO: Help message for this and previous one.
