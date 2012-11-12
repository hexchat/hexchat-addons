# add your own aliases here

alias allaway {
  set msg $_rest
  if { $msg == "" } { set msg "I am away." }
  foreach s [servers] {
    command $s "away $msg"
  }
  complete
}

alias allback {
  foreach s [servers] {
    command $s "away"
  }
  complete
}
