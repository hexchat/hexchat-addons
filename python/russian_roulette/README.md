Russian Roulette
================
* Manages Russian Roulette games.
* Default triggers (you can either use #r or #roulette):
  * #r  - Fires the gun (FFA/FreeForAll game).
  * #r challenge <nick> [nick] [nick] ... - Starts a new challenge with nicks.
  * #r challenge - Fires the gun (current challenge).
  * #r challenge_reset - Resets the current challenge. Used by its creator.
  * #r help - Shows quick help.

Installation:
=============
* To install, move roulette.py to your path_to_HexChat_config/addons directory.

Requirements:
=============
* XChat Python scripting interface plugin.

Games Management:
=================
* Each channel has its own FFA game.
* A person cannot participate in two challenges at once. He can, however, play
  in both FFA games and challenges.

Bugs/To-do:
===========
* Nicknames aren't linked to a particular channel/network. So starting a game
  in channel A, going to channel B and trying to start a new game in it will
  trigger channel A's gun (and send the output there) instead.
* Multiple networks aren't handled well.
