alias uptime {
 /say [bold][me]'s Uptime:[bold] [string trim [exec uptime]]
}

proc bold { } {
  return "\002"
}

