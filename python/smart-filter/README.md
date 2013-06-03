Smart Filter
================
* A plugin that filters join/nick change/part/quit messages, in order to reduce
  spam.

Installation:
=============
* To install, move filter.py to your path_to_HexChat_config/addons directory.

Requirements:
=============
* XChat Python scripting interface plugin.

Behavior:
=========
The plugin will:
* Eat all join messages, unless the user spoke recently and parted/rejoined.
* If the user speaks for the first time after joining, a '(joined Xs ago)'
  message will be appended to his message, to let us know when he joined.
* Part/nick change messages will be eaten unless the user spoke recently.
