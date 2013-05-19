ctypes
======

Pure python hexchat addons demonstrating how to interface directly with
GTK via ctypes.

tabxhider
=========

When using the tabs channel switcher mode, tabxhider will remove the X button
upon loading. To restore the X button, remove the addon and restart xchat.
If the X button reappears due to switching between different switcher methods
or positions, /py reload tabxhider to have the X disappear again.

treenumbers
===========

This plugin is used to hide the tree view channel expander, the lines, and
collapse all channels to the same indent level. In addition to this, for those
of us familiar with irssi and its ALT-Number keybindings, this plugin also
prepends the tab number in front of all tabs so that we can ALT-Number quickly
to the channel we want.

If you have more than 9 channels, I recommend binding ALT-0, ALT-Q, ALT-W,
..., ALT-P to tabs 10 through 20, respectively.

Requirements
-------------

* Any version of HexChat 2.9.6b1 or greater that supports Python
* Python 2.7, none of these addons have been tested nor developed on Python3

tabxhider implementation method
-------------------------------

tabxhider is implemented by performing a depth-first-search through the
GtkWindow hierarchy to locate the third button with a NULL label, once
this button is found, it is forced to invisible.

treenumbers implementation method
---------------------------------

Iterates the widget hierarchy to find a GtkTreeView that has a GtkTreeStore
as its model. Upon finding that, iterate through the model entries and
retrieves the label for each entry, each label is modified to be prefixed
with "(Number) " and this prefix is replaced if it already exists in the label.

Hooks on JOIN, PART and PRIVMSG are used to force a label update when the
previously encountered tablist is different from the current tab list. The
use of only these 3 events can cause an occasionaly desync between numbers
and tab names.

Notes
-----

This implementation does not perform any platform checking to detect whether
it is Windows or Linux, and thus the correct GTK libraries may not be loaded
by the plugin. It is currently configured for use on Windows.

Resources
-------------
* http://docs.python.org/2/library/ctypes.html - python ctypes tutorial
* https://developer.gnome.org/gobject/stable/ - gobject documentation
* https://developer.gnome.org/glib/stable/ - glib documentation
* https://developer.gnome.org/gtk2/stable/ - gtk2 documentation
