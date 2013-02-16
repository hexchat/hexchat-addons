hexchat-amip
============

A very simple python plugin that lets you announce the currently played song from any player utilizing AMIP.

Requirements
-------------

* Any version of HexChat that supports Python ( http://hexchat.org/ )
* A music player of your choice that is supported by AMIP :)
* AMIP for your music player ( http://amip.tools-for.net/wiki/start )


Configuration
-------------

Since it relies on AMIP, you set it up using the AMIP configuration tool. 

1. Open the AMIP Configurator
2. Navigate to "Other Integrations -> File/E-Mail"
3. Under "File Integration", choose a path and check the "Enabled" checkbox.
4. Under the different play state tabs, set up your announcement string. (see: Help)
5. Check "Update file every second"
6. Set AMIP_FILE in the python script to the path your exported AMIP text file.
7. Done!

Commands
-------------

/np - Announces your currently played song.

Help
-------------

A suggested announcement string would be: "np: %name (%4) [%pm:%ps/%min:%sec] %br~kbps/%sr~kHz", which would look something like this:
* Speljohan_ np: Candlemass - The Well Of Souls (Doomed For Live (Disc 2)) [02:38/08:53] 320kbps/44kHz

Resources
-------------

http://amip.tools-for.net/wiki/manual/amip - Useful for setting up the AMIP announcement string.
