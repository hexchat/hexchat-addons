from __future__ import unicode_literals, print_function
# ONoticeFormat for HexChat
# Original tcl version opvoice 0.2 by Sodoma and fixed by lizardo 2014
# Ported from tcl to Python & HexChat by sacarasc, 2016, License: Unlicense
# Maintained by BurritoBazooka

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

"""Command hook and associated settings hooks for formatting notices directed at
IRC channel users by status."""

import hexchat
import time
import json
from string import ascii_letters, digits

__module_name__ = str("ONoticeFormat")
__module_author__ = str("sacarasc")
__module_version__ = str("1.3.7")
__module_description__ = str("Formats some of them there ONotices")

C_RESET = "\017"

nickname = hexchat.get_pluginpref(__module_name__ + "name")
colorpairs_json = hexchat.get_pluginpref(__module_name__ + "colorpairs")
if colorpairs_json is None:
    colorpairs = {}
else:
    colorpairs = json.loads(colorpairs_json)

colorpairs_defaults = {
                        "o": [0, 2],
                        "oh": [0, 5],
                        "ov": [0, 3],
                        "_time": [0, 12]
                    }

def getname():
    if nickname is None:
        return hexchat.get_info("nick")
    else:
        return nickname

def colorcode(*colors):
    colors = map(lambda n: str(n).zfill(2), colors)
    return "\003" + ",".join(colors)

def colorcode_by_name(colorname):
    # colorname: "o", "oh" etc., or "_time"
    colorname = colorname.lower()

    if colorname in colorpairs:
        return colorcode(*colorpairs[colorname])
    elif colorname in colorpairs_defaults:
        return colorcode(*colorpairs_defaults[colorname])
    else:
        return "" # not found, use nothing.

def save_colorpairs():
    if len(colorpairs) > 0:
        colorpairs_json = json.dumps(colorpairs)
        if not hexchat.set_pluginpref(__module_name__ + "colorpairs", colorpairs_json):
            raise BaseException("Plugin ONoticeFormat couldn't save colorpairs table.")
    else:
        hexchat.del_pluginpref(__module_name__ + "colorpairs")

setcolorusage = "Usage: O_SETCOLOR <'o'|'oh'|'ov'|'_time'> <'default'|foreground_colorcode> [background_colorcode]"

def setcolor_by_name_cmd(w, weol, userdata):
    # names are limited to those in colorpairs_defaults
    # first param should be a name of a command
    # second param should be a number or the string 'default'
    # third param should be a number or not provided
    # examples:
    # /o_setcolor o default
    # /o_setcolor ov 12 0
    # /o_setcolor oh 12
    # /o_setcolor _time 0 4
    if len(w) < 3:
        print("Not enough parameters. " + setcolorusage)
        return hexchat.EAT_HEXCHAT
    else:
        colorname = w[1]

        if colorname not in colorpairs_defaults:
            print("No such color, valid colors: {}".format(list(colorpairs_defaults.keys())))
            return hexchat.EAT_HEXCHAT

        if w[2].lower() == "default":
            if colorname in colorpairs:
                del colorpairs[colorname]
                save_colorpairs()
                print("Color {} made default.".format(colorname))
            else:
                print("Color {} already default.".format(colorname))
        else:
            colorpair = list(map(int, w[2:4]))
            colorpairs[colorname] = colorpair
            save_colorpairs()
            print("New color code set for name '{}'.".format(colorname))
        previewtext =  ascii_letters + digits
        print("Preview: {}{}{}".format(colorcode_by_name(colorname), previewtext, C_RESET))
        return hexchat.EAT_HEXCHAT

def setname_cmd(word, word_eol, userdata):
    global nickname

    if len(word) > 1:
        hexchat.set_pluginpref(__module_name__ + "name", word_eol[1])
        nickname = word_eol[1]
        print("opvoice name set to:", getname())
    else:
        print("Provide a name. Usage: O_SETNAME <Name>")
    return hexchat.EAT_ALL

def delname_cmd(word, word_eol, userdata):
    global nickname
    hexchat.del_pluginpref(__module_name__ + "name")
    nickname = None
    print("opvoice name set to default (your IRC nick)")
    return hexchat.EAT_ALL

def noticeformat_cmd(w, weol, userdata):
    if len(w) > 1:
        format_kws = {}
        format_kws['chan'] = hexchat.get_info("channel")
        blank_msg1, format_kws['prefix'] = userdata

        format_kws['msg1'] = blank_msg1.format(getname())
        format_kws['msg2'] = time.strftime("%H:%M")
        format_kws['ccode1'] = colorcode_by_name(w[0])
        format_kws['ccode2'] = colorcode_by_name("_time")
        format_kws['R'] = C_RESET
        format_kws['rest'] = weol[1]

        hexchat.command("notice {prefix}{chan} {ccode1}{msg1}{R} {ccode2}{msg2}{R} {rest}".format(**format_kws))
    else:
        print("Provide a message. Usage: {} <message>".format(w[0]))

    return hexchat.EAT_HEXCHAT

def no_cmd(w, weol, userdata):
    if len(weol) > 1:
        hexchat.command("notice " + weol[1])
    else:
        hexchat.command("notice")
    return hexchat.EAT_HEXCHAT

hexchat.hook_command("o", noticeformat_cmd, userdata=("{} to o", "@"), help="Send a notice to channel operators. Usage: O <message>")
hexchat.hook_command("oh", noticeformat_cmd, userdata=("{} to o/h", "%@"), help="Send a notice to chanops and halfops. Usage: OH <message>")
hexchat.hook_command("ov", noticeformat_cmd, userdata=("{} to o/v", "@+"), help="Send a notice to chanops and voiced users. Usage: OV <message>")
hexchat.hook_command("no", no_cmd, help="Send a notice. Alias for /NOTICE")

hexchat.hook_command("o_setname", setname_cmd, help="Usage: O_SETNAME <Name>")
hexchat.hook_command("o_delname", delname_cmd)
hexchat.hook_command("o_setcolor", setcolor_by_name_cmd, help=setcolorusage)

print("{} version {} loaded.".format(__module_name__, __module_version__))
