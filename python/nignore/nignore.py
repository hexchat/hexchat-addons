# Copyright (c) 2015 noteness
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in
#  all copies or substantial portions of the Software.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE
import hexchat
import sys
import fnmatch
__module_name__ = 'NIgnore'
__module_version__ = '0.2.4'
__module_description__ = 'Ignores nick changes.'
__module_author__ = 'noteness'
ignores = []
hook = None

def saveconf():
    global ignores
    hexchat.set_pluginpref(__module_name__+'_ignores', ",".join(ignores))

def loadconf():
    global ignores
    ign = hexchat.get_pluginpref(__module_name__+'_ignores')
    if ign:
        ignores = ign.split(',')
    else:
        ignores = []

def setignorer(word, word_eol, userdata):
    global ignores
    if len(word) !=  2:
        hexchat.command('HELP '+ word[0])
        return 
    ignores.append(word[1])
    hexchat.prnt('user {0} successfully added to ignore list'.format(word[1]))
    saveconf()

def unset(word, word_eol, userdata):
    global ignores
    if len(word)  != 2 :
        hexchat.command('HELP '+ word[0])
        return
    num =int(word[1])
    if  not len(ignores) >= num:
        hexchat.prnt('Are you sure that a such index is there?')
        return hexchat.EAT_NONE
    temp = ignores[num]
    del ignores[num]
    hexchat.prnt('user {0} successfully removed from ignore list'.format(temp))
    saveconf()


def listi(word, word_eol, userdata):
    global ignores
    allo = []
    for x in ignores:
        num = str(ignores.index(x)) + ": " + x
        allo.append(num)
    alli = ", ".join(allo)
    toprnt = "Ignored users are: "+alli if ignores else "No hosts are ignored"
    hexchat.prnt(toprnt)

def on_nick(word, word_eol, userdata):
    global ignores
    host =word[0]
    for x in ignores:
        if fnmatch.fnmatch(host, x):
            return hexchat.EAT_ALL
    return hexchat.EAT_NONE

help = {
    "nignore": """/NIGNORE <nick>!<ident>@<host> (Wildcards accepted)
    eg: /NIGNORE *!*@*12.34.spammer.com
    Ignores the nick changes made by the user (even the user list won't change)
    To deactivate, see /help UNNIGNORE
    See also: /help UNNIGNORE, /help LNIGNORE""",

    "unnignore": """/UNNIGNORE <index>
    eg: /UNNIGNORE 0
    Removes the user from the nick change ignore list
    See also: /help NIGNORE, /help LIGNORE""",

    "lnignore": """/LNIGNORE
    eg: /LNIGNORE
    Shows the users currently ignore by the /NIGNORE command
    See also: /help NIGNORE, /help UNNIGNORE"""
}

def unhook(dt):
    if hook:
        hexchat.unhook(hook)

def unload_cb(dt):
    hexchat.prnt("{0} module is unloaded".format(__module_name__))

loadconf()
hook = hexchat.hook_server('NICK',on_nick,priority=hexchat.PRI_HIGHEST)
hexchat.hook_command('NIGNORE',setignorer,help=help['nignore'])
hexchat.hook_command('LNIGNORE',listi,help=help['lnignore'])
hexchat.hook_command('UNNIGNORE',unset,help=help['unnignore'])
hexchat.hook_unload(unhook)
hexchat.hook_unload(unload_cb)
print("{0} module version {1} by {2} loaded.".format(__module_name__, __module_version__, __module_author__))