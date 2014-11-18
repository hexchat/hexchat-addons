cmus_hexchat
============

Hexchat plugin to control Cmus

main repo: https://github.com/Kiniamaro/cmus_hexchat/

##usage
  ``/cmus <command>``
``` 
   COMMANDS          USAGE
   ------------------------------
   playing           prints the currently playing song in the channel.
   next              Skip forward in playlist.
   previous          Skip backwards in playlist.
   toggle            toggle pause/play.
   help              prints the help.
```
``/notice <name> !playing`` upon receiving this notice you will send the asker the currently playing song (see ``playing``)

```
ex:
    <user1> !playing
    <self> I am listening to: Air - La femme d'argent
```




## Installation

###Linux/mac
- copy ``cmus_hexchat.py`` in ``~/.config/hexchat/addons/``

###Windows
- copy ``cmus_hexchat.py`` in ``%APPDATA%\HexChat\addons\``
