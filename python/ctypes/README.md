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

Requirements
-------------

* Any version of HexChat that supports Python ( http://hexchat.org/ )

Implementation Method
---------------------

tabxhider is implemented by performing a depth-first-search through the
GtkWindow hierarchy to locate the third button with a NULL label, once
this button is found, it is forced to invisible.

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
