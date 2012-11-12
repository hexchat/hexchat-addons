#
# Script for common irc commands.
#

proc splitsrc { } {
  uplevel "scan \$_src \"%\\\[^!\\\]!%\\\[^@\\\]@%s\" _nick _ident _host"
}

proc rand { {range 100} } {
  return [expr {int(rand()*$range)}]
}

proc randrange { lowerbound upperbound } {
 return [expr {int(($upperbound - $lowerbound + 1) * rand() + $lowerbound)}]
}

proc unixtime { } {
  return "[clock seconds]"
}

proc stripcolor {intext} {
  regsub -all "(\002|\003\[0-9\]*,*\[0-9\]*|\026|\037)" $intext "" outtext
  return $outtext
}

proc color { {arg {}} } {
  return "\003$arg"
}

proc bold { } {
  return "\002"
}

proc underline { } {
  return "\037"
}

proc reverse { } {
  return "\026"
}

proc reset { } {
  return "\017"
}

proc ::exit { } {
  puts "Using 'exit' is bad"
}

proc privmsg { dest text } {
  raw "PRIVMSG $dest :$text"
}

proc notice { dest text } {
  raw "NOTICE $dest :$text"
}

proc action { dest text } {
  raw "PRIVMSG $dest :\001ACTION $text\001"
}

proc ctcp { dest text } {
  raw "PRIVMSG $dest :\001$text\001"
}

proc ping { dest } {
  raw "PRIVMSG $dest :\001PING [clock seconds]\001"
}

proc joinchan { channel {key {}} } {
  raw "JOIN $channel :$key"
}

proc partchan { channel text } {
  raw "PART $channel :$text"
}

proc mode { args } {
  raw "MODE [join $args " "]"
}

proc quit { text } {
  raw "QUIT :$text"
}

proc op { channel nicks } {
  raw "MODE $channel +[string repeat o [llength $nicks]] $nicks"
}

proc deop { channel nicks } {
  raw "MODE $channel -[string repeat o [llength $nicks]] $nicks"
}

proc voice { channel nicks } {
  raw "MODE $channel +[string repeat v [llength $nicks]] $nicks"
}

proc unvoice { channel nicks } {
  raw "MODE $channel -[string repeat v [llength $nicks]] $nicks"
}

proc ban { channel nicks } {
  command "/ban $nicks"
}

proc unban { channel hosts } {
  raw "MODE $channel :-[string repeat b [llength $hosts]] $hosts"
}

proc is_ip_addr { addr } {
  return [regexp {([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)} $addr]
}

proc longip { ip } {
  global tcl_precision
  set tcl_precision 17
  set result 0
  regexp {([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)} $ip s b3 b2 b1 b0
  if { ![string compare $ip $s] } {
    set total 0
    set total [expr $total + double($b3) * pow(256,3)]
    set total [expr $total + double($b2) * pow(256,2)]
    set total [expr $total + double($b1) * pow(256,1)]
    set total [expr $total + double($b0) * pow(256,0)]
    set result [format "%10.0f" $total]
  }
  return $result
}

proc mask { type mask } {
  set n "*"
  set u "*"
  set a "*"
  scan $mask "%\[^!\]!%\[^@\]@%s" n u a
  set n [string trimleft $n "@+"]
  set u [string trimleft $u "~"]
  set h $a
  set d ""
  if { [is_ip_addr $a] } {
      set a [split $a .]
      set a [lreplace $a end end *]
  } else {
      set a [split $a .]
      if { [llength $a] > 2 } { set a [lreplace $a 0 0 *] }
  }
  set d [join $a .]
  switch "$type" {
    "0" { return "*!$u@$h" }
    "1" { return "*!*$u@$h" }
    "2" { return "*!*@$h" }
    "3" { return "*!*$u@$d" }
    "4" { return "*!*@$d" }
    "5" { return "$n!$u@$h" }
    "6" { return "$n!*$u@$h" }
    "7" { return "$n!*@$h" }
    "8" { return "$n!*$u@$d" }
    "9" { return "$n!*@$d" }
  }
  return "$n!$u@$h"
}

proc randomline { filename } {

  set position [rand [expr [file size $filename] - 1024]]

  set fd [open $filename r]
  catch {
    seek $fd $position
    set text [read $fd 1024]
  }
  close $fd

  set lines [split $text \n]
  set lineno [randrange 1 [expr [llength $lines] - 1]]

  return [lindex $lines $lineno]
}
