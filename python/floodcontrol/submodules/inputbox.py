from __future__ import unicode_literals
# Author & maintainer: BurritoBazooka <burritobazooka@gmail.com>
# License: Unlicense
###########################################
# This is free and unencumbered software released into the public domain.

# Anyone is free to copy, modify, publish, use, compile, sell, or distribute this 
# software, either in source code form or as a compiled binary, for any purpose, 
# commercial or non-commercial, and by any means.

# In jurisdictions that recognize copyright laws, the author or authors of this 
# software dedicate any and all copyright interest in the software to the public domain.
# We make this dedication for the benefit of the public at large and to the detriment 
# of our heirs and successors.  We intend this dedication to be an overt act of 
# relinquishment in perpetuity of all present and future rights to this software 
# under copyright law.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTBILITY, FITNESS FOR A 
# PARTICULAR PURPOSE AND NONINFRINGEMENT, IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR 
# ANY CLAIM, DAMAGES, OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR 
# OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR 
# OTHER DEALINGS IN THE SOFTWARE.
###########################################
import hexchat
import time
import threading

"""Functions and commands for manipulating HexChat's inputbox.
For use as a HexChat addon or a submodule of other addons."""

CURSORPLACEHOLDER="\ufdd9" # Non-character character used to keep track of the cursor's position while manipulating strings.
# TODO: Doing so has the side effect of not being able to replace strings where the cursor is.
# TODO: might need to escape CURSORPLACEHOLDER if user happens to give input which includes it already.

def is_mainthread():
    try:
        return threading.main_thread() is threading.current_thread()
    except AttributeError: # < py3.4
        return isinstance(threading.current_thread(), threading._MainThread)

def get_with_cursor():
    cursorposition = hexchat.get_prefs("state_cursor")
    inputbox = get()
    return "".join((inputbox[:cursorposition], CURSORPLACEHOLDER, inputbox[cursorposition:]))

def set_with_cursor(newtext):
    cursorposition = newtext.find(CURSORPLACEHOLDER)
    newtext = newtext.replace(CURSORPLACEHOLDER, "")
    set(newtext, cursorposition)

def append(s):
    """Appends text to the inputbox while trying to preserve the cursor position."""
    inputbox = get_with_cursor()
    if not inputbox.endswith(CURSORPLACEHOLDER):
        inputbox += s
        set_with_cursor(inputbox)
    else:
        inputbox = inputbox.replace(CURSORPLACEHOLDER, "") + s
        set(inputbox)

def add_at_cursor(s):
    """Adds text to the inputbox before the current cursor position."""
    inputbox = get_with_cursor()
    inputbox = inputbox.replace(CURSORPLACEHOLDER, s + CURSORPLACEHOLDER)
    set_with_cursor(inputbox)

def replace(old, new, count=-1):
    """Replaces text in the inputbox while trying to preserve the cursor position."""
    inputbox = get_with_cursor()
    inputbox = inputbox.replace(old, new, count)
    set_with_cursor(inputbox)

def set(newtext, new_cursor_position=None):
    # HexChat seems to crash (sometimes? always?) when we change the inputbox
    # from outside the main thread.
    # We use HexChat's timers when we aren't on the main thread.
    def cb(*args):
        _set(newtext, new_cursor_position)
        return False
    if is_mainthread():
        cb()
    else:
        hexchat.hook_timer(20, cb)

def _set(newtext, new_cursor_position=-1):
    if new_cursor_position < 0:
        new_cursor_position = len(newtext)
    hexchat.command("settext " + newtext)
    #time.sleep(0.1)
    hexchat.command("setcursor {}".format(new_cursor_position))

def get():
    return hexchat.get_info("inputbox")

def append_cmd(words, words_eol, *args):
    append(words_eol[1])
    return hexchat.EAT_HEXCHAT

def add_cmd(words, words_eol, *args):
    add_at_cursor(words_eol[1])
    return hexchat.EAT_HEXCHAT

def replace_cmd(words, *args):
    replace(words[1], words[2])
    return hexchat.EAT_HEXCHAT

if __name__ == "__main__":
    __module_name__ = str("Inputbox manipulation")
    __module_description__ = str("For manipulating HexChat's inputbox, complimenting the SETTEXT and SETCURSOR commands.")
    __module_version__ = str("1")

    hexchat.hook_command("APPENDTEXT", append_cmd, help="Usage: APPENDTEXT <new text>, add text to the input box")
    hexchat.hook_command("ADDTEXT", add_cmd, help="Usage: ADDTEXT <new text>, add text to the input box before the current cursor position")
    hexchat.hook_command("REPLACETEXT", replace_cmd, help="Usage: REPLACETEXT <\"original text\"> <\"new text\">, replace some text in the input box")
