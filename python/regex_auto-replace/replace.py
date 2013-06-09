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
    """ Gets the inputbox's text, perform substitutions and replaces it.
    
    This function is called every time a key is pressed. It will stop if that
    key isn't ENTER (without modifiers, e.g. SHIFT + ENTER), or if the input
    box is empty.
    
    """
    if not(word[0] == "65293" and word[1] == "16"):
        return
    msg = xchat.get_info('inputbox')
    if msg is None:
            return
    for pattern, repl in zip(re_pattern, re_repl):
        msg = re.sub(pattern, repl, msg)
    xchat.command("settext %s" % msg)

def add_regex(word, word_eol, userdata):
    """ Adds a regex pattern / replacement. """
    try:
        arg_pattern, arg_repl = get_regex(word_eol[1])
    except TypeError:
        return xchat.EAT_ALL
    except IndexError:
        xchat.prnt("Two arguments must be specified.")
        return xchat.EAT_ALL
    re_pattern.append(arg_pattern)
    re_repl.append(arg_repl)
    save_pref()
    return xchat.EAT_ALL

def remove_regex(word, word_eol, userdata):
    """ Removes a regex pattern / replacement couple by their index. """
    try:
        index = int(word[1])
    except ValueError:
        xchat.prnt("Argument must be an integer")
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
    """ Lists all saved regex pattern/repl couples. """
    xchat.prnt("Patterns:     %s" % ', '.join(re_pattern))
    xchat.prnt("Replace with: %s" % ', '.join(re_repl))
    return xchat.EAT_ALL

def get_regex(s):
    """ Gets two arguments from the string s. The first is the regex pattern,
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
        xchat.prnt("Two arguments must be specified.")
        return None

def save_pref():
    """ Saves preferences. """
    xchat.set_pluginpref("autoreplace_re_pattern", str(re_pattern))
    xchat.set_pluginpref("autoreplace_re_repl", str(re_repl))
    xchat.prnt("Saved.")


xchat.hook_print('Key Press', send_message)
xchat.hook_command("RE_ADD", add_regex)
xchat.hook_command("RE_REM", remove_regex)
xchat.hook_command("RE_LIST", list_regex)

print "\00304", __module_name__, "successfully loaded.\003"
