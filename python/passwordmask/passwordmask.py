__module_name__ = "passwordmask"
__module_version__ = "0.0.1"
__module_description__ = "mask passwords in the inputbox"
__module_author__ = "mniip"

# The below regexes determine what counts as a command containing a password.
# Regexes are checked in the given order. In case of a match, the regex should
# include exactly one capture (named or unnamed) containing the password.
# Location of the capture will be used to mask the original command.
patterns = [
        r"^/(?:msg\s+nickserv|(?:quote\s+)?ns)\s+(?:(?:identify|id|(?:ghost|release|regain|recover|set\s+password|group)\s+\S+|setpass\s+\S+\s+\S+)\s+(.*)|register\s+(.*)\s+.*)$",
        r"^/(?:msg\s+chanserv|(?:quote\s+)?cs)\s+(?:(?:identify|set\s+password)\s+(.*)|register\s+\S+\s+(\S+).*)$",
        r"^/(?:quote\s+)?pass\s+(.*)$",
        r"^/(?:quote\s+)?oper\s+\S+\s+(.*)$",
        r"^/(?:msg\s+operserv|(?:quote\s+)?os)\s+(?:identify|id)\s+(.*)$"
    ]
placeholder = '*'

import hexchat
import re

unmasked_command = None
old_cursor = None

def group_name(match):
    names = []
    groups = match.groups()
    for i in range(len(groups)):
        if groups[i] != None:
            names.append(i + 1)
    for k in match.groupdict():
        names.append(k)
    if not len(names):
        raise ValueError("Regex {} did not return a capture".format(repr(match.re.pattern)))
    if len(names) > 1:
        raise ValueError("Regex {} returned multiple captures".format(repr(match.re.pattern)))
    return names[0]

def update_textbox(match, group):
    start = match.start(group)
    end = match.end(group)
    string = match.string
    text = string[:start] + placeholder * (end - start) + string[end:]
    cur_pos = hexchat.get_prefs("state_cursor")
    hexchat.command("settext " + text)
    hexchat.command("setcursor " + str(cur_pos))

def reset_textbox(command, cur):
    hexchat.command("settext " + command)
    hexchat.command("setcursor " + str(cur))

def update(key_type):
    global unmasked_command, old_cursor
    try:
        textbox = hexchat.get_info("inputbox")
        cur_pos = hexchat.get_prefs("state_cursor")
        if unmasked_command == None:
            for pat in patterns:
                match = re.search(pat, textbox, flags = re.I)
                if match:
                    group = group_name(match)
                    unmasked_command = textbox
                    old_cursor = cur_pos
                    update_textbox(match, group)
                    break
        else:
            if key_type == "edit":
                old_prefix, old_suffix = unmasked_command[:old_cursor], unmasked_command[old_cursor:]
                new_prefix, new_suffix = textbox[:cur_pos], textbox[cur_pos:]
                if len(new_prefix) <= len(old_prefix):
                    prefix = old_prefix[:len(new_prefix)]
                else:
                    prefix = old_prefix + new_prefix[len(old_prefix):]
                if len(new_suffix) <= len(old_suffix):
                    if len(new_suffix):
                        suffix = old_suffix[-len(new_suffix):]
                    else:
                        suffix = ""
                else:
                    if len(old_suffix):
                        suffix = new_suffix[:-len(old_suffix)] + old_suffix
                    else:
                        suffix = new_suffix
                command = prefix + suffix
            elif key_type == "reset":
                command = textbox
            else:
                command = unmasked_command
            for pat in patterns:
                match = re.search(pat, command, flags = re.I)
                if match:
                    group = group_name(match)
                    unmasked_command = command
                    old_cursor = cur_pos
                    update_textbox(match, group)
                    break
            else:
                reset_textbox(command, cur_pos)
                unmasked_command = None
                old_cursor = None
    except:
        unmasked_command = None
        old_cursor = None
        raise

def keypress(w, we, u):
    global unmasked_command, old_cursor
    key, state, string, len_str = w
    key = int(key)
    len_str = int(len_str)
    if unmasked_command != None and key in [65293, 65421]: # [<Enter>, <Num-Enter>]
        reset_textbox(unmasked_command, old_cursor)
        unmasked_command = None
        old_cursor = None
    else:
        if len_str or key in [65288, 65535]: # [<Bksp>, <Del>]
            key_type = "edit"
        elif key in [65362, 65364]: # [<Up>, <Down>]
            key_type = "reset"
        else:
            key_type = "move"
        hexchat.hook_timer(0, update, key_type)

hexchat.hook_print("Key Press", keypress)
