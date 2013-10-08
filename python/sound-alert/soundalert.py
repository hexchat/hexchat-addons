import hexchat, sys, os, random
from threading import Thread

__module_name__ = "Sound Alert" 
__module_version__ = "3.0"
__module_description__ = "Plays a random sound on alert from Hexchat/share/sounds \
by default or the directory specified by \"/soundalert set my_sounds/directory\""


hexchat.prnt("Sound Alert plugin loaded.")

def parse(word, word_eol, userdata):
	if len(word) < 3:
		hexchat.prnt("Not enough arguments given. See /help soundalert")

	else:
		if word[1] == "set":
			if os.path.isdir(word_eol[1]):
				hexchat.set_pluginpref("soundalert_dir", word_eol[1])

			else:
				hexchat.prnt("Not a valid directory.")

	return hexchat.EAT_ALL

def find_sounds():
	if hexchat.get_pluginpref("soundalert_dir") != None:
		return hexchat.get_pluginpref("soundalert_dir")

	else:
		if os.name == "nt":
			paths = ["C:\Program Files\HexChat\share\sounds", "C:\Program Files (x86)\HexChat\share\sounds"]

		elif os.name == "posix":
			paths = ["/sbin/HexChat/share/sounds", "/usr/sbin/HexChat/share/sounds", "/usr/local/bin/HexChat/share/sounds"]

		else:
			return False

		for path in paths:
			if os.path.isdir(path):
				hexchat.set_pluginpref("soundalert_dir", path)
				return path

		return False


def process(word, word_eol, userdata):
	do_thread = Thread(target=play_sound)
	do_thread.start()

def randomize():
	sound_dir = find_sounds()
	if sound_dir == False:
		return False

	os.chdir(sound_dir)
	file_list = list()

	for file in os.listdir("./"):
		file_list.append(file)
	
	random.shuffle(file_list)
	return file_list[0]

def play_sound():
	sound = randomize()

	if sound == False:
		hexchat.prnt("Could not find default share/sounds directory, and no sounds directory is specified. See /help soundalert.")

	if os.name == "nt":
		import winsound
		winsound.PlaySound('%s' % sound, winsound.SND_FILENAME)

	elif os.name == "posix":
		import pyxine
		xine = pyxine.Xine()
		stream = xine.stream_new()
		stream.open(sound)
		stream.Play()

hexchat.hook_command("soundalert", parse, help="/soundalert set <directory> -- Sets a directory for Sound Alert to pull sounds from.")
hexchat.hook_print("Channel Action Hilight", process)
hexchat.hook_print("Channel Msg Hilight", process)
hexchat.hook_print("Private Message", process)