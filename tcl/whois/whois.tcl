# RPL_WHOISREGNICK
on 307 mywhois {
  set whodata [split $_rest " "]
  print "---\t[color 12]\[[color][lindex $whodata 0][color 12]\][color] [string range [lrange $whodata 1 end] 1 end]"
  complete EAT_ALL
}

# RPL_WHOISUSER
on 311 mywhois {
  set whodata [split $_rest " "]
  print "---\t[color 12]\[[color][lindex $whodata 0][color 12]\][color] [lindex $whodata 1]@[lindex $whodata 2]"
  print "---\t[color 12]\[[color][lindex $whodata 0][color 12]\][color] Info: [string range [lrange $whodata 4 end] 1 end]"
  complete EAT_ALL
}

# RPL_WHOISSERVER
on 312 mywhois {
  complete EAT_ALL
}

# RPL_WHOISIDLE
on 317 mywhois {
  set whodata [split $_rest " "]
  set idle [clock format [expr 25200+[lindex $whodata 1]] -format "%T"]
  print "---\t[color 12]\[[color][lindex $whodata 0][color 12]\][color] idle $idle, signon: [clock format [lindex $whodata 2] -format "%a, %b %d %T"]"
  complete EAT_ALL
}

# RPL_ENDOFWHOIS
on 318 mywhois {
  complete EAT_ALL
}

# RPL_WHOISCHANNELS
on 319 mywhois {
  set whodata [split [string trim $_rest] " "]
  print "---\t[color 12]\[[color][lindex $whodata 0][color 12]\][color] [string range [lrange $whodata 1 end] 1 end]"
  complete EAT_ALL
}

# RPL_WHOISSPECIAL
on 320 mywhois {
  set whodata [split $_rest " "]
  print "---\t[color 12]\[[color][lindex $whodata 0][color 12]\][color] [string range [lrange $whodata 1 end] 1 end]"
  complete EAT_ALL
}

# RPL_WHOISBOT
on 335 mywhois {
  set whodata [split $_rest " "]
  print "---\t[color 12]\[[color][lindex $whodata 0][color 12]\][color] [string range [lrange $whodata 1 end] 1 end]"
  complete EAT_ALL
}

# RPL_WHOISHOST
on 378 mywhois {
  set whodata [split $_rest " "]
  print "---\t[color 12]\[[color][lindex $whodata 0][color 12]\][color] [lindex $whodata end]"
  complete EAT_ALL
}

proc color { {arg {}} } {
  return "\003$arg"
}

