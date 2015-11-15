nicenicks
============

Hexchat script which colourizes all the nicks in a channel. It's different from the built-in colouring system because that one frqeuently assigns two people in a channel the same colour when there are still MANY unused colours.

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

###Linux/mac
- copy ``nicenicks.py`` in ``~/.config/hexchat/addons/``

###Windows
- copy ``nicenicks.py`` in ``%APPDATA%\HexChat\addons\``
