EasyXdcc
========

XDCC download manager with support for simultaneous queues on different channels, servers and bots, as well as saving/loading queue state.

__Current Version: 1.3__ ([changelog](#changelog))

Current Home: [Ultrabenosaurus/EasyXdcc](https://github.com/Ultrabenosaurus/EasyXdcc)

## Credit

This is not originally my work, I just found it and made some modifications. The site seems to be down even though the file is still accessible and searching for over an hour looking for an updated version returned nothing helpful, so I decided to host it here.

The original is by Bouliere Tristan and can be found in the [XChat plugin repository](http://xchat.org/cgi-bin/search.pl?str=easyxdcc&cat=0&Submit=Search). I attempted to email Bouliere using the address given in the source code to tell him about this repo, but I got a bounceback saying it didn't exist.

## Install

Simply copy `EasyXdcc.py` to your IRC client's plugins folder. Original version designed for XChat 2, my version is tested and working in HexChat 2.10.1. May or may not work in any other client.

Confirm it is loaded and active in your client's plugin manager.

:shipit:

## Usage

Make sure you have joined a channel with access to the bot you want files from, then use one of the following commands:

* `/XDCC ADD [bot_name] [n°_pack]`
* `/XDCC ADDL [bot_name] [n°_pack_beg] [n°_pack_end]`
* `/XDCC ADDM [bot_name] [n°_pack_1] [n°_pack_2] [...]`

You can use `/XDCC QUEUE` or `/XDCC QUEUE [bot_name]` to view the current queue.

If it doesn't start downloading stuff for you automatically enter `/XDCC START` to get things going. To make it start downloading automatically in the future, enter `/XDCC AUTO ON` or toggle it form the EasyXdcc menu option.

The start/stop/auto-start and load/save/show queue functions are also available from a custom menu added to your client's interface. Additionally, the menu entry for auto-start will tell you whether the feature is currently on or off.

## All Commands

```
 Queue a pack :
 /XDCC ADD [bot_name] [n°_pack]

 Queue a pack list :
 /XDCC ADDL [bot_name] [n°_pack_beg] [n°_pack_end]

 Queue non-sequential pack list :
 /XDCC ADDM [bot_name] [n°_pack_1] [n°_pack_2] [...]

 See pack queue :
 /XDCC QUEUE

 See pack queue for a bot :
 /XDCC QUEUE [bot_name]

 Withdraw a pack from queue :
 /XDCC RMP [bot_name] [n°pack]

 Withdraw a pack list from queue :
 /XDCC RMPL [bot_name] [n°pack_beg] [N°pack_end]

 Withdraw a non-sequential pack list from queue :
 /XDCC RMPM [bot_name] [n°_pack_1] [n°_pack_2] [...]

 Withdraw a bot from queue :
 /XDCC RMBOT [bot_name]

 Stop EasyXdcc :
 /XDCC STOP

 Start EasyXdcc :
 /XDCC START

 Show auto-start status :
 /XDCC AUTO

 Toggle auto-start :
 /XDCC AUTO [ON|OFF]

 Save Queue :
 /XDCC SAVE

 Load Queue :
 /XDCC LOAD

 Delete saved Queue file :
 /XDCC PURGE
 ```

## TODO

* use JSON for queue file
  * I hope python knows how to do JSON natively...
* refactor for latest HexChat python interface guidelines
  * handle both XChat and HexChat interfaces or just go with HexChat now?
* make it smarter
  * file transfer status
  * automatic retry of failed transfers

## Changelog

### 1.3

* auto-start feature
  * help text
  * menu item
* handle loss of connection
* fix queue deletion to include in-memory queue

### 1.2

* auto-load queue file when plugin loads
* OS detection for paths
* create paths if they don't exist

### 1.1

* normalise indentation
* non-sequential pack list add/remove
* queue deletion
* menu entry for help text
* Windows path for queue file
