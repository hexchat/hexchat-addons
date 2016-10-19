EasyWinampControl 1.3.9
=======================

Forked from <http://easywinampcontrol.mandragor.org/>, and then from <https://github.com/KevinLi/EasyWinampControl>
Licensed under the [GNU Lesser General Public License (LGPL)](https://www.gnu.org/licenses/lgpl.html)

What's new
----------
Version 1.3.9

* Added support for a disabled "Show playlist number" winamp option (no longer removes the first word in the artist's name)
* Fixed additionnal space after song name

Version 1.3.8

* Used new hexchat header, rebranded everything to work with it

Version 1.3.7

* Sample Rate is now always converted into Hz to standardize between Winamp (which reports Khz) and foobar2000 with the Winamp plugin (which reports Hz) 

Version 1.3.6

* Fixed support for scrolling titles in taskbar
* Fixed additionnal space before song name

Version 1.3.5

* Fully compatible with x32 AND x64 XChat/Hexchat
* Full Unicode support

Version 1.3.2

* Shortened command names
* Fixed function to play next track
* Fixed "Could not get current song's elapsed time... !?"

Version 1.3.1

* Added */wp curr* to print current track

Version 1.3

* Compacted two commands into one
* Fancy */wp next*

Download
--------

* [Version 1.3.9 (32-bit)](https://dl.hexchat.net/addons/hexchat_winampctrl_x86.dll)  
* [Version 1.3.9 (64-bit)](https://dl.hexchat.net/addons/hexchat_winampctrl_x64.dll)  

Installation
------------
1. Install either Winamp or foobar2000 with the [foo_winamp_spam](https://github.com/RazielZ/foo_winamp_spam/releases) component.
2. Install the dll in *%appdata%\HexChat\addons*
3. Go to *Settings > User Commands...* and add a command named "dispcurrsong", which is what the plugin will display when **/wp** is used, and with a command such as "me is now playing: &7 [%5/%6] %3kbps - %2Hz".

```
%2    Sample rate  
%3    Bitrate  
%4    Number of channels  
%5    Elapsed time  
%6    Track's length  
&7    Track's title
```

If foobar2000 is being used with foo_winamp_spam, &7 can be configured in *Library > Configure > Winamp API Emulator*
To have */wp* output, for example, *(Nick) is listening to: Shpongle - Nothing is Something Worth Doing [2:15/6:25]*:

1. foobar2000's foo\_winamp\_spam should be set with something like "[%artist% - ]$if(%title%,%title%,%_filename%)".
2. HexChat's "dispcurrsong" user command should be set to "me is listening to: &7[%5/%6]"

How to use EasyWinampControl
----------------------------

```
/wp      Displays current track to the channel/user  
/wp b    Plays the previous track  
/wp p    Plays/restarts playing the current track  
/wp q    Pauses/continues the current track  
/wp s    Stops playing the current track  
/wp n    Plays the next track, and prints its title  
/wp c    Displays the current track
```

Compilation
-----------
* Make sure to add the plugin.def file to linker command line options, as detailed in the HexChat C plugin documentation.

Known Bugs
----------
* None

Testing
-------
* Tested with HexChat 2.9.1, 2.9.5 x64 and Winamp 5.63
* Tested with HexChat 2.9.3, 2.9.5 x64 and foobar2000 v1.2.9 with foo_winamp_spam Winamp API Emulator 0.99
