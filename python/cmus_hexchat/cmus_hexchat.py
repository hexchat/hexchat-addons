# cmus_hexchat V1.0
# Copyright (C) 2014 Kiniamaro (Vdyotte@gmail.com)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#

import subprocess

import hexchat

__module_name__ = "cmus_hexchat"
__module_version__ = "1.0"
__module_description__ = "cmus controls for hexchat"

commands = {
    "PLAYING": "playing",
    "NEXT": "next",
    "PREVIOUS": "previous",
    "TOGGLE": "toggle",
    "HELP": "help"
    }

def print_help():
    hexchat.prnt("\nCOMMANDS          USAGE")
    hexchat.prnt("------------------------------")
    hexchat.prnt("playing           prints the currently playing song in the channel.")
    hexchat.prnt("next              Skip forward in playlist.")
    hexchat.prnt("previous          Skip backwards in playlist.")
    hexchat.prnt("toggle            toggle pause/play.")
    hexchat.prnt("help              prints the help")

def get_status():
    try:
        output = subprocess.check_output(["cmus-remote", "-Q"])
    except subprocess.CalledProcessError:
       return ["stopped"]
   
    return output.split("\n")

def get_tag(tag_name):
    status = get_status()
    for s in status:
        if s.split(" ")[1] == tag_name:
            return s.replace("tag " + tag_name + " ", "")
            
def print_song():
    output = get_status()
    if not "stopped" in output[0]:
        song = get_tag("artist") + " - " + get_tag("title")
    else:
        song = "Nothing!"
    hexchat.command("me is listening to: " + song)
    
def on_command(args, args_eol, userdata):
    if len(args) > 1:
        if args[1] == commands['PLAYING']:
            print_song()
        elif args[1] == commands['TOGGLE']:
            subprocess.call(["cmus-remote", "-u"])
        elif args[1] == commands['NEXT']:
            subprocess.call(["cmus-remote", "-n"])
        elif args[1] == commands['PREVIOUS']:
            subprocess.call(["cmus-remote", "-p"])
        elif args[1] == commands['HELP']:
            print_help()
            
    return hexchat.EAT_ALL

hexchat.hook_command("cmus", on_command, help="/cmus <command> sends the " 
                        "command to cmus, /cmus help, for more info")
