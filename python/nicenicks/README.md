nicenicks
============

Hexchat script which colourizes all the nicks in a channel. It's different from the built-in colouring system because that one frequently assigns two people in a channel the same colour when there are still MANY unused colours.

The nicks in the events called "Channel Message" and "Channel Action" will be recoloured by this script.

## Features
- Colourize nicks based on least-recently-used colour. (When a user who has no colour starts talking, it picks the colour that hasn't been used in the longest time.)
- Assign specific colours to specific nicks. This steals colours from other users. ;)

## Usage

Command | Example | Comment
------- | ------- | ----------
/NICENICKS [on/off] |    | turn the script on or off (use without argument for status)
/SETCOLOR |         | show colour mappings
/SETCOLOR [nick] [color] | /SETCOLOR TriangleMan 12 | permanently maps [color] to [nick] \(stealing the colour from other users if necessary)
/SETCOLOR -[nick] | /SETCOLOR -TriangleMan | remove [nick] from colour mapping table
/COLORTABLE |    | display a list of colours
/NICEDEBUG [on/off] |    | Enable or disable the display of debug messages (use without argument for status)
/NICENICKS_DUMP |    | dump the internal dictionary of all known nick colours

## Installation

### Linux/mac
- copy ``nicenicks.py`` in ``~/.config/hexchat/addons/``

### Windows
- copy ``nicenicks.py`` in ``%APPDATA%\HexChat\addons\``

### XChat users

You should use [this old version of nicenicks](https://github.com/hexchat/hexchat-addons/blob/ce72d9d3f8a556493ed43e5c8d3a562afaa8317b/python/nicenicks/nicenicks.py). I encountered [a problem](https://github.com/hexchat/hexchat-addons/blob/7e9e0dcc2f73f58172a260a7050496b08d902c9a/python/nicenicks/nicenicks.py#L29) when trying to port the new version back to XChat. The effect of this problem is all messages and actions being output twice. You will not receive updates or new changes, and events are handled differently (intercepted raw commands converted to prnt events, instead of intercepted events simply recoloured)... unless somebody wants to help us solve that :)
- copy [this old version of nicenicks](https://github.com/hexchat/hexchat-addons/blob/ce72d9d3f8a556493ed43e5c8d3a562afaa8317b/python/nicenicks/nicenicks.py) to the XChat profile directory. [Look here to see where your profile directory is](http://xchatdata.net/Using/ProfileDirectory).
