__module_name__ = 'Regex Replace'
__module_version__ = '1.0'
__module_description__ = 'Replaces matching regex patterns'

import re
import ast
import shlex
import xchat


# Load saved patterns
re_pattern = xchat.get_pluginpref("autoreplace_re_pattern")
re_repl = xchat.get_pluginpref("autoreplace_re_repl")

# If previous patterns are found, convert the string to a list.
# Otherwise, create an empty list.
if re_pattern is not None and re_repl is not None:
    re_pattern = ast.literal_eval(re_pattern)
    re_repl = ast.literal_eval(re_repl)
else:
    re_pattern = []
    re_repl = []


def send_message(word, word_eol, userdata):
    """Gets the inputbox's text, perform substitutions and replaces it.

    This function is called every time a key is pressed. It will stop if that
    key isn't Enter or if the input box is empty.

    KP_Return (keypad Enter key) is ignored, and can be used if you don't want
    any substitutions to happen.

    """
    if not(word[0] == "65293"):
        return
    msg = xchat.get_info('inputbox')
    if msg is None:
            return
    for pattern, repl in zip(re_pattern, re_repl):
        msg = re.sub(pattern, repl, msg)
    xchat.command("settext %s" % msg)

def add_regex(word, word_eol, userdata):
    """Adds a regex pattern / replacement."""
    try:
        arg_pattern, arg_repl = get_regex(word_eol[1])
    except TypeError:
        return xchat.EAT_ALL
    except IndexError:
        xchat.prnt("/RE_ADD <PATTERN> <REPLACEMENT>")
        return xchat.EAT_ALL
    re_pattern.append(arg_pattern)
    re_repl.append(arg_repl)
    save_pref()
    return xchat.EAT_ALL

def remove_regex(word, word_eol, userdata):
    """Removes a regex pattern / replacement couple by their index."""
    try:
        index = int(word[1])
    except ValueError:
        xchat.prnt("Argument must be an index. Use /RE_LIST to find it.")
        return xchat.EAT_ALL
    try:
        re_pattern.pop(index)
        re_repl.pop(index)
    except IndexError:
        xchat.prnt("Entry doesn't exist. Use /RE_LIST to list all entries.")
        return xchat.EAT_ALL
    save_pref()
    return xchat.EAT_ALL

def list_regex(word, word_eol, userdata):
    """Lists all saved regex pattern/repl couples."""
    if len(re_pattern) == 0:
        xchat.prnt("No entries found. Use /RE_ADD to add entries.")
        return xchat.EAT_ALL
    for i, (pattern, repl) in enumerate(zip(re_pattern, re_repl)):
        xchat.prnt("%s- '%s' is replaced by: '%s'" % (i, pattern, repl))
    return xchat.EAT_ALL

def get_regex(s):
    """Gets two arguments from the string s. The first is the regex pattern,
    the second the replacement.

    """
    try:
        regex = shlex.split(s)
    except ValueError,e:
        xchat.prnt(str(e))
        return None
    if len(regex) == 2:
        return regex[0], regex[1]
    else:
        xchat.prnt("/RE_ADD <PATTERN> <REPLACEMENT>")
        xchat.prnt("You can use quotes if your arguments contain spaces.")
        return None

def save_pref():
    """Saves preferences."""
    xchat.set_pluginpref("autoreplace_re_pattern", str(re_pattern))
    xchat.set_pluginpref("autoreplace_re_repl", str(re_repl))
    xchat.prnt("Preferences saved.")


xchat.hook_print('Key Press', send_message)
xchat.hook_command("RE_ADD", add_regex,
                   help=("/RE_ADD <PATTERN> <REPLACEMENT>\n"
                         "Use quotes if the arguments contain spaces.\n"
                         "You need to double escape special regex characters"
                         " if you want to use the literal value, and single"
                         " escape characters that might be interpreted by"
                         " Python (e.g. quotation marks \")."))
xchat.hook_command("RE_REM", remove_regex,
                   help=("/RE_REM <INDEX>\n"
                         "Use /RE_LIST to list all pattern/repl couples,"
                         " and find the index of the item you want removed."))
xchat.hook_command("RE_LIST", list_regex,
                   help=("/RE_LIST\n"
                         "Lists all pattern/repl couples."))

print "\00304", __module_name__, "successfully loaded.\003"
