import hexchat, sys, os, random
from threading import Thread

__module_name__ = "Sound Alert" 
__module_version__ = "4.4"
__module_description__ = "Plays a random sound on alert from Hexchat/share/sounds \
by default or the directory specified by \"/soundalert set my_sounds/directory\""

# Winsound is installed by default
if os.name == "nt":
  import winsound

# Pyxine is a third-party module which must be installed
elif os.name =="posix":
  try:
    import pyxine

  except ImportError:
    print("Pyxine is missing! Install xine, then run 'pip install pyxine' to use this plugin.")
    raise

else:
  raise Exception("This operating system is not supported.")

class SoundAlert():
  def __init__(self):
    hexchat.prnt("Sound Alert plugin loaded.")

    self.sound_directory = self.find_sound_directory()
    self.file_list = self.find_sounds()

    if hexchat.get_pluginpref("soundalert_active") == None:
      hexchat.set_pluginpref("soundalert_active", True)

    if hexchat.get_pluginpref("soundalert_active") == False:
      hexchat.prnt("Alerts are currently disabled. Re-enable them with /soundalert on")

  def commands(self, word, word_eol, userdata):
    if len(word) < 2:
      hexchat.prnt("Not enough arguments given. See /help soundalert")
    
    else:      
      if word[1] == "set":
        if len(word) < 3:
          hexchat.prnt("No directory specified.")
        
        if os.path.isdir(word_eol[2]):
          hexchat.set_pluginpref("soundalert_dir", word_eol[2])

        else:
          hexchat.prnt("Not a valid directory.")

      elif word[1] == "on":
        self.enable()

      elif word[1] == "off":
        self.disable()

      elif word[1] == "get":
        hexchat.prnt("Currently set sound directory: {}".format(hexchat.get_pluginpref("soundalert_dir")))

      elif word[1] == "test":
        self.spawn(None, None, None)

      else:
        hexchat.prnt("No such command exists.")

    return hexchat.EAT_ALL

  def disable(self):
    hexchat.prnt("Sound alerts will now be off until you enable them again with /soundalert on.")
    hexchat.set_pluginpref("soundalert_active", False)

  def enable(self):
    hexchat.prnt("Sound alerts are now on.")
    hexchat.set_pluginpref("soundalert_active", True)

  def find_sound_directory(self):
    if os.path.isdir(hexchat.get_pluginpref("soundalert_dir")):
      return hexchat.get_pluginpref("soundalert_dir")

    else:
      if os.name == "nt":
        paths = ["C:\\Program Files\\HexChat\\share\\sounds", "C:\\Program Files (x86)\\HexChat\\share\\sounds", "%appdata%\\HexChat\\sounds"]

      elif os.name == "posix":
        paths = ["/sbin/HexChat/share/sounds", "/usr/sbin/HexChat/share/sounds", "/usr/local/bin/HexChat/share/sounds"]

      else:
        return False

      for path in paths:
        if os.path.isdir(path):
          hexchat.set_pluginpref("soundalert_dir", path)
          return path

      return False

  def find_sounds(self):
    if not self.sound_directory:
      return False

    os.chdir(self.sound_directory)
    file_list = list()

    for root, dirs, files in os.walk("./"):
      for sound_file in files:
        file_list.append(sound_file)
    
    return file_list

  def play_sound(self):
    sound = random.choice(self.file_list)
    active = hexchat.get_pluginpref("soundalert_active")

    if not active:
      return

    if sound == False:
      hexchat.prnt("Could not find default share/sounds directory, and no sounds directory is specified. See /help soundalert.")

    if os.name == "nt":
      winsound.PlaySound(sound, winsound.SND_FILENAME ^ winsound.SND_ASYNC)

    elif os.name == "posix":
      xine = pyxine.Xine()
      stream = xine.stream_new()
      stream.open(sound)
      stream.Play()

    return True

  def spawn(self, word, word_eol, userdata):
    do_thread = Thread(target=self.play_sound)
    do_thread.start()

alert = SoundAlert()

hexchat.hook_command("soundalert", alert.commands, help="/soundalert set <directory> -- Sets a directory for Sound Alert to pull sounds from.\n/soundalert get -- Debug command, displays the currently set sound directory.\n/soundalert on -- Enables sounds when highlighted.\n/soundalert off -- Disables sounds when highlighted.\n/soundalert test -- Plays a sound from the set or default sound directory.")
hexchat.hook_print("Channel Action Hilight", alert.spawn)
hexchat.hook_print("Channel Msg Hilight", alert.spawn)
hexchat.hook_print("Private Message", alert.spawn)