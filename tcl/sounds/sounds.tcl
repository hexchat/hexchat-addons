alias play {
  play $_rest
  complete
}

proc play { file } {

  ##########################################################################
  # DELETE THIS STUFF AFTER YOU EDIT THE SETTINGS
  ##########################################################################
  print "*** You need to edit sounds.tcl for your configuration first."
  return
  ##########################################################################

  set sound_dir "/YOUR/SOUND/DIRECTORY"
  set sound_command "/usr/bin/artsplay"

  if { [file exists "$sound_dir/$file"] } {
    set cmd "$sound_command $sound_dir/$file &"
  } elseif { [file exists $file] } {
    set cmd "$sound_command $file &"
  } elseif { [file exists "[xchatdir]/$file"] } {
    set cmd "$sound_command [xchatdir]/$file &"
  } else {
    print "Unable to find $file"
    return
  }
  eval "exec $cmd"

}
