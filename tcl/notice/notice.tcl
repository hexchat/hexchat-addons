# Hey guys,
# This script is based on tclplugin for hexchat.
# Dependence: In order to make it works, please install tclplugin.so for hexchat and load tclplugin.tcl first!
# Author: pagu - test (at) plcnet.org
# Purpose: Handles notices and server notices in self hexchat windows.
on SNOTICE servNotice {
	###
	splitsrc
        /query -nofocus (Snotice)
	set pattern "^:.*"
	if {[regexp $pattern $_raw match]} {
		if {[string trim $_dest] != ""} {
			if {[string trim $_dest] == "*"} {
				print (Snotice) "[bold][color 12]\[[color]$_nick[color 12]\][bold]\t[color] $_raw"
				complete EAT_XCHAT
			} else {			
				set debugmsg [lrange [regexp -inline ($_dest.*) $_raw] 1 end]
				set clearbck [regsub -all {\{|\}} $debugmsg ""]
				set clrnick [string trimleft $clearbck "$_dest"]
				print (Snotice) "[bold][color 12]\[[color]$_nick[color 12]\][bold]\t[color] $clrnick"
				complete EAT_XCHAT
			}
		} else {
			print (Snotice) "[bold][color 12]\[[color]$_nick[color 12]\][bold]\t[color] $_raw"
			complete EAT_XCHAT
		}
	}
}
on NOTICE allnotice {
	splitsrc
        /query -nofocus (Notice)
	if { "$_nick" == "" } {
		set noticemessage [lindex [split $_raw :] 2]
        	print (Notice) "[bold][color 12]\[[color]$_nick[color 12]\][bold]\t[color]: $noticemessage"
        	complete EAT_XCHAT
	} else {
		set noticemessage [lrange $_raw 2 end]
		print (Notice) "[bold][color 12]\[[color]$_nick[color 12]\][bold]\t[color]: $noticemessage"
        	complete EAT_XCHAT
	}
}

puts "\[Plugin\]\t \[[color 4]Notice[color]\] [color 3]loaded[color]"
