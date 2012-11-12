#
# Ping whoever says !pingme in a channel and send them a private reply.
#

set ::pinglist [list]

on !pingme pingmecode {
  splitsrc
  set nick [string toupper $_nick]
  if { [lsearch -exact $::pinglist $nick] == -1 } {
    lappend ::pinglist $nick
    /ping $_nick
  }
}

on XC_PINGREP pingmecode {
  set _nick [lindex $_raw 1]
  set nick [string toupper $_nick]
  set index [lsearch -exact $::pinglist $nick]
  if { $index == -1 } {
    complete
  }
  set ::pinglist [lreplace $::pinglist $index $index]
  notice $_nick "[color 4]$_nick PING reply:[color] [lindex $_raw 2] seconds"
  complete EAT_XCHAT
}

proc color { {arg {}} } {
  return "\003$arg"
}

