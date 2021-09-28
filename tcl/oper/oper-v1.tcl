# oper.tcl plugin for Xchat
# Feel free to edit this plugin!
# License: http://en.wikipedia.org/wiki/BSD_licenses
#       Revision 1.2
#               - Services bug fixed
#		- Fixed bug with ircd connections ( /connect ircd.server.example ) notices
#	version: 1.3 [24.09.2021]
#		- changed text handling
#		- addedd support for solanum-1.0-dev and UnrealIRCD
#
# Please send any questions, suggestions or comments to e-force(at)PLCNeT(dot)org
#

#
# Do not EDIT bellow, until you know TCL !
#
on WALLOPS mywall {
        splitsrc
		set operText [lrange $_raw 2 end]
                /query -nofocus (WALLOPS)
                print (WALLOPS) "[bold][color 12]\[[color]$_nick[color 12]\][bold]\t[color]: $operText"
                complete EAT_XCHAT
 # $_raw - everytihng in received by the server, provided by tcl.so library
 # /query -nofocus (locops)
 # $_nick $_ident $_host = nickname!ident@domain.name
 # $_src = domain
 # $_dest = type
 # $_rest = text
}

on GLOBOPS mylocop {
	splitsrc
	set operText [lrange $_raw 2 end]
	#set operText [lindex [split $_raw :] 2]
	/query -nofocus (GlobalOps)
	print (GlobalOps) "[bold][color 12]\[[color]$_nick[color 12]\][bold]\t[color]: $operText"
	complete EAT_XCHAT
}


proc bold { } {
  return "\002"
}

proc color { {arg {}} } {
  return "\003$arg"
}
puts "\[Plugin\]\t \[[color 4]Oper[color]\] [color 3]loaded[color]"

