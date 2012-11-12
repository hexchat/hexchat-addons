
on XC_CHANACTION myaction {
  if { [string equal -nocase "[me]" [lindex $_raw 1]] } {
    print "[color 5]*\t[lindex $_raw 1] [lindex $_raw 2]"
    complete EAT_XCHAT
  } else {
    if { [string match -nocase "*[me]*" [lindex $_raw 2]] } {
      set thatcontext [getcontext]
      set thiscontext [findcontext]
      if { ![string equal $thiscontext $thatcontext] } {
        print $thiscontext "[color 4]*\t[lindex $_raw 1]/[channel $thatcontext] [lindex $_raw 2]"
        print "[color 4]*\t[lindex $_raw 1] [lindex $_raw 2]"
        complete EAT_XCHAT
      }
    }
  }
  complete
}

on PRIVMSG mynick02 {
  if { [string match -nocase "*[me]*" $_rest] } {
    set thatcontext [getcontext]
    set thiscontext [findcontext]
    if { ![string equal $thiscontext $thatcontext] } {
      splitsrc
      print $thiscontext "[color 4]*\t[bold]$_nick/[channel $thatcontext] said:[bold] [color] $_rest"
      print "[color 4][bold]$_nick:[bold][color]\t$_rest"
      complete EAT_XCHAT
    }
  }
  complete
}

proc splitsrc { } {
  uplevel "scan \$_src \"%\\\[^!\\\]!%\\\[^@\\\]@%s\" _nick _ident _host"
}

proc color { {arg {}} } {
  return "\003$arg"
}

proc bold { } {
  return "\002"
}
