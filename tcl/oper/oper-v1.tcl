# oper.tcl plugin for Xchat
# Designed for ShakeIT IRC Network
# Feel free to edit this plugin!
# License: http://en.wikipedia.org/wiki/BSD_licenses
#       Revision 1.2
#               - Services bug fixed
#		- Fixed bug with ircd connections ( /connect ircd.server.example ) notices
#
# Please send any questions, suggestions or comments to e-force(at)PLCNeT(dot)org
#

#
# Do not EDIT bellow, until you know TCL !
#

on WALLOPS mywall {
        splitsrc
        if { "$_src" == "services.bg" } {
                /query -nofocus (WALLOPS)
                print (WALLOPS) "[bold][color 12]\[[color]$_nick[color 12]\][bold]\t[color]:$_rest"
                complete EAT_ALL
        }
        if { [string match -nocase "*irc*" $_src] } {
                /query -nofocus (WALLOPS)
                print (WALLOPS) "[bold][color 12]\[[color]$_nick[color 12]\][bold]\t[color]:$_rest"
                complete EAT_ALL
        }
        if { "$_dest" == "LOCOPS" } {
                /query -nofocus (LOCOPS)
                print (LOCOPS) "[bold][color 12]\[[color]$_nick[color 12]\][bold]\t[color]\($_ident@$_host\): $_rest"
                complete EAT_XCHAT
        }
        if { "$_dest" != "LOCOPS" } {
                /query -nofocus (WALLOPS)
                print (WALLOPS) "[bold][color 12]\[[color]$_nick[color 12]\][bold]\t[color]: $_rest"
                complete EAT_XCHAT
        }
 # /query -nofocus (locops)
 # $_nick $_ident $_host = nickname!ident@domain.name
 # $_src = domain
 # $_dest = type
 # $_rest = text
}


proc bold { } {
  return "\002"
}

proc color { {arg {}} } {
  return "\003$arg"
}

