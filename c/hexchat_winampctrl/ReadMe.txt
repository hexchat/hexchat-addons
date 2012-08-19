##EasyWinampControl 1.3.5##
***
Forked from <http://easywinampcontrol.mandragor.org/>, and then from <https://github.com/KevinLi/EasyWinampControl>
Licensed under the [GNU Lesser General Public License (LGPL)](http://www.gnu.org/licenses/lgpl.html)

###What's new###
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

###Download###
* [Version 1.3.5 (32bit)](/EasyWinampControl/Compiled/winampctrl_x32.dll)  
* [Version 1.3.5 (64bit)](/EasyWinampControl/Compiled/winampctrl_x64.dll)  

###Installation###
* Copy the plugin to XChat's plugin directory (ex: C:\Program Files\XChat-WDK\plugins\).
* Start XChat (or XChat-WDK). If the plugin hasn't automatically loaded, load it at the menu in "**Window > Plugins and Scripts**"
* Go to "**Settings > Advanced > User Commands...**", and add a command named **"dispcurrsong"**, which is what the plugin will display when **/wp** is used, and with a command such as "**me is listening to: &7[%5/%6]**".

`
%2    Sample rate  
%3    Bitrate  
%4    Number of channels  
%5    Elapsed time  
%6    Track's length  
&7    Track's title
`

* If foobar2000 is being used with foo_winamp_spam, &7 can be configured in **Library > Configure > Winamp API Emulator**
* To have */wp* output, for example, **`(Nick) is listening to: Shpongle - Nothing is Something Worth Doing [2:15/6:25]`**:
  * foobar2000's foo\_winamp_spam should be set with something like
     * **`[%artist% - ]$if(%title%,%title%,%_filename%)`**.
  * XChat's "**dispcurrsong**" user command should be set to
     * **`me is listening to: &7[%5/%6]`**
  * User-defined commands can be found at
     * **Settings -> Advanced -> User Commands**.

###How to use EasyWinampControl###

    /wp      Displays current track to the channel/user  
    /wp b    Plays the previous track  
    /wp p    Plays/restarts playing the current track  
    /wp q    Pauses/continues the current track  
    /wp s    Stops playing the current track  
    /wp n    Plays the next track, and prints its title  
    /wp c    Displays the current track

###Compilation###

* If compiling for 64bit, comment out line 28 of winamp.h.
* If compiling for 32bit, leave line 28 as is.

###Known Bugs###

* Asian language characters are displayed as question marks

###Testing###
* Tested with XChat-WDK 1503 x64 and foobar2000 1.1.11 with foo_winamp_spam 0.90aFix
