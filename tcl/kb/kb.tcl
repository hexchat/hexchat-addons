alias kb {
        foreach user [users] {
                if {[lindex $_rest 0]==[me]} {
                        print "Trying to kick yourself is not healthy!"
                        complete EAT_ALL
                        break
                }
                if {[lindex $_rest 0]==[lindex $user 0]} {
                        set n "[string range [lindex $user 0] [string last "@" [lindex $user 0]] end]"
                        set h "[string range [lindex $user 1] [string last "@" [lindex $user 0]] end]"
                        set r "[lrange $_rest 1 end]"
                        set bmask "[mask 3 $n!$h]"
                        if { "$r" == "" } {
                                set r "Go to bed, stupido!"
                                /kick $n $r
                                /ban $bmask
                        } else {
                                /kick $n $r
                                /ban $bmask
                        }
                }
        }
        complete EAT_ALL
}

alias kbn {
        foreach user [users] {
                if {[lindex $_rest 0]==[me]} {
                        print "Trying to kick yourself is not healthy!"
                        complete EAT_ALL
                        break
                }
                if {[lindex $_rest 0]==[lindex $user 0]} {
                        set r "[lrange $_rest 1 end]"
                        set n "[string range [lindex $user 0] [string last "@" [lindex $user 0]] end]"
                        if { "$r" == "" } {
                                set r "This nickname is forbidden! Please change it and come back again."
                                set bmask "$n!*@*"
                                /kick $n $r
                                /ban $bmask
                        } else {
                                set bmask "$n!*@*"
                                /kick $n $r
                                /ban $bmask
                        }
                }
        }
        complete EAT_ALL
}
