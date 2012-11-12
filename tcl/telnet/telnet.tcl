
# close socket if needed
if { [info exists ::telnetsock] } {
  close $::telnetsock
  unset ::telnetsock
  unset ::telnettab
}

proc telnetHandler {sock} {
  set l [gets $sock]
  if {[eof $sock]} {
     close $sock
     print $::telnettab "Closed connection at [clock format [clock seconds]]"
     unset ::telnetsock
  } else {
    print $::telnettab "$l"
  }
}

alias @telnet {
  set ::telnettab [getcontext]
  if { [info exists ::telnetsock] } {
    puts $::telnetsock "$_rest\n"
    print $::telnettab "> $_rest"
  }
  complete
}

alias telnet {

  /query telnet

  if { [info exists ::telnetsock] } {
    close $::telnetsock
    unset ::telnetsock
    print $::telnettab "Closed connection at [clock format [clock seconds]]"
  }

  if { $_rest == "" } {
    complete
  }

  set host [lindex $_rest 0]
  if { $host == "" } {
    set host 127.0.0.1
  }

  set port [lindex $_rest 1]
  if { $port == "" } {
    set port 23
  }

  set ::telnetsock [socket $host $port]

  fconfigure $::telnetsock -buffering line -blocking 0
  fileevent $::telnetsock readable [list telnetHandler $::telnetsock]

  complete

}