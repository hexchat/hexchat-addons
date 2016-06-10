Sound Alert
=====
A plugin that plays a random sound whenever you receive an alert.
Optional TF2 Taunts available [here](http://github.com/captain-lightning/Sound-Alert). 

### Requirements
- Python scripting interface plugin for Hexchat.
- Xine, for linux users.

### Installation

##### Windows
- To install, move soundalert.py into ```%appdata%\HexChat\addons```. Once there, it will load automatically.
- Move alert sounds into share/sounds within Hexchat's install directory, ```%appdata\HexChat\sounds```. Alternatively, specify your own sounds folder with "/soundalert set <path>", see: [Usage](#Usage).

##### Linux
- Install Xine. On Ubuntu: ```apt-get install xine```
- Install PyXine with ```pip install pyxine```
- To install, move soundalert.py into ```~/.config/HexChat/addons```. Once there, it will load automatically.
- Move alert sounds into share/sounds within Hexchat's install directory, ```/usr/local/bin/HexChat/share/sounds```. Alternatively, specify your own sounds folder with ```/soundalert set <path>```, see: [Usage](#Usage).

### Features
- Plays all formats Xine does in Linux. (AAC, AC3, ALAC, AMR, FLAC, MP3, RealAudio, Shorten, Speex, Vorbis, WMA)
- Plays only .wav in Windows. Unfortunately adding support for more formats would involve compiling and installing many dependencies from source. Savvy users using 2.7 or older may try using [PyMedia](http://www.lfd.uci.edu/~gohlke/pythonlibs/#pymedia).
- Automatically searches for and plays from the share/sounds folder within Hexchat's install directory by default.

### Usage
- ```/soundalert set <path>``` -- Specifies a directory to play sounds from.
- ```/soundalert get``` -- Display currently set sound path.
- ```/soundalert on``` -- Turns on alerts. Enabled by default.
- ```/soundalert off``` -- Disables alerts until re-enabled.
- ```/soundalert test``` -- Play a sound from the currently set sound path.
