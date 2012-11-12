#
# SEE INSTRUCTIONS AT THE BOTTOM
#

if { [info exists ::ircservices] } {
  unset ::ircservices
}

proc RegisteredNick { nick server nickserv warning password } {
   lappend ::ircservices [list $nick $server $nickserv $warning $password]
}

on NOTICE nickserv01 {
  set mynick [me]
  set myhost [network]
  foreach entry $::ircservices {
    if {
      ![nickcmp $_src [lindex $entry 2]] &&
      ![nickcmp $mynick [lindex $entry 0]] &&
      ![nickcmp $myhost [lindex $entry 1]] &&
      ([string first "[lindex $entry 3]" $_rest] != -1)
    } {
      splitsrc
      /msg $_nick "IDENTIFY [lindex $entry 4]"
      complete
    }
  }
}

####################################
# ENTER YOUR REGISTERED NICKS HERE #
####################################

# Params are:
#  Your registered nickname.
#  Name of the network in the server list (not the server name)
#  Full hostmask of NickServ.
#  Part of the phrase NickServ sends to you to let you know the nick is registered.
#  Your password.

RegisteredNick YourNick FreeNode NickServ!NickServ@services. "This nickname is owned by someone else" YourPassword
RegisteredNick YourNick NewNet NickServ!nickserv@services.newnet.net "This nickname is registered and protected" YourPassword
