Sound Alert
=====
A plugin that plays a random sound whenever you receive an alert.
Optional TF2 Taunts available [here](http://github.com/captain-lightning/Sound-Alert). 

### Installation
- To install, move soundoff.py into %appdata%/HexChat/addons for Windows, ~/.config/HexChat/addons for linux. Once there, it will load automatically.

### Requirements
- Python scripting interface plugin.
- Xine, for linux users.

### Usage
- Defaults to the share/sounds directory within Hexchat's install directory, which it will automatically search for. If you wish to use a different directory, set it with "/soundalert set C:\My Special Directory\Sounds_Galore\Spaces Are Okay"
- Move whatever sounds you want played into either of the above directories.
- Supports only .wav in Windows.
- Plays all formats Xine does in Linux. (AAC, AC3, ALAC, AMR, FLAC, MP3, RealAudio, Shorten, Speex, Vorbis, WMA)