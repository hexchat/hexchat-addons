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
  set whodata [split $_rest " "]
  print "---\t[color 12]\[[color][lindex $whodata 0][color 12]\][color] [string range [lrange $whodata 1 end] 0 end]"
  complete EAT_ALL
}

# Pagu
on 313 mywhois {
  set whodata [split $_rest " "]
  print "---\t[color 12]\[[color][lindex $whodata 0][color 12]\][color] [string range [lrange $whodata 1 end] 1 end]"
  complete EAT_ALL
}

# RPL_WHOISIDLE
on 317 mywhois {
  set whodata [split $_rest " "]
  #set idle [clock format [expr 25200+[lindex $whodata 1]] -format "%T"]
  #print "---\t[color 12]\[[color][lindex $whodata 0][color 12]\][color] idle $idle, signon: [clock format [lindex $whodata 2] -format "%a, %b %d %T"]"
  set rawidle [lindex $whodata 1] 
    if { $rawidle >= 86400 } {
        set idleformat "%dd %Hh %Mm %Ss"
    } elseif { $rawidle >= 3600 } {
        set idleformat "%Hh %Mm %Ss"
    } elseif { $rawidle >= 60 } {
        set idleformat "%Mm %Ss"
    } else {
        set idleformat "%Ss"
    }
  set idle [timefmt $rawidle $idleformat]
  set signon [clock format [lindex $whodata 2] -format "%Y/%m/%d %T"]
  print "---\t[color 12]\[[color][lindex $whodata 0][color 12]\][color] idle $idle, signon: $signon"
  complete EAT_XCHAT
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

# Pagu
on 327 mywhois {
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

proc timefmt { secs { fmt "%H:%M:%S" } } {

    if { ! [string is integer -strict $secs] } {
     error "first argument must be integer"
    }

    set d [expr {$secs/86400}]              ; set D [string range "0$d" end-1 end]
    set h [expr {($secs%86400)/3600}]       ; set H [string range "0$h" end-1 end]
    set m [expr {(($secs%86400)%3600)/60}]  ; set M [string range "0$m" end-1 end]
    set s [expr {(($secs%86400)%3600)%60}]  ; set S [string range "0$s" end-1 end]

    set p "%% % %s $s %S $S %m $m %M $M %h $h %H $H %d $d %D $D"
    set str [string map $p $fmt]

    return $str;

}
