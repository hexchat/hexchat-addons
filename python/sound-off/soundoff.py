import xchat, sys, os, random
from threading import Thread

__module_name__ = "Sound Off" 
__module_version__ = "2.1" 
__module_description__ = "Plays a random sound from /share/sounds,\nhooks into PRIVMSG and works whenever alerted."

def process(word, word_eol, userdata):
	do_thread = Thread(target=play_sound)
	do_thread.start()

def randomize():
	os.chdir(xchat.get_prefs("sound_dir"))
	file_list = list()
	for file in os.listdir("./"):
		file_list.append(file)
	random.shuffle(file_list)
	return file_list[0]

def play_sound():
	sound = randomize()
	if os.name == "nt":
		import winsound
		winsound.PlaySound('%s' % sound, winsound.SND_FILENAME)
	elif os.name == "posix":
		import pyxine
		xine = pyxine.Xine()
		stream = xine.stream_new()
		stream.open(sound)
		stream.Play()
	
xchat.hook_print("Channel Action Hilight", process)
xchat.hook_print("Channel Msg Hilight", process)
xchat.hook_print("Private Message", process)