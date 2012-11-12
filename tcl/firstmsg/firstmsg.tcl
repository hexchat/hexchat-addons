# will play a sound if you also have sounds.tcl

on XC_TABOPEN myfirstmsg01 {

  switch [string index [channel] 0] {
    "#" -
    "&" -
    "(" -
    "" { return }
  }

  catch { play attention.wav }
  print "Private conversation with [channel]."
  complete

}
