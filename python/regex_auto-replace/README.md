Regex Auto Replace
================
* Replaces regex patterns in the user's input when the Enter key is pressed.
* Commands:
  * /RE_ADD <regex pattern> <replacement> - Adds a pattern/repl couple.
  * /RE_REM <index> - Removes the pattern/repl couple.
  * /RE_LIST - Lists added couples.

Installation:
=============
* To install, move replace.py to your path_to_HexChat_config/addons directory.

Requirements:
=============
* XChat Python scripting interface plugin.

Notes:
=========
* While only one round of substitutions is performed, each pattern is checked
  for in order, which means multiple substitutions might happen. For example:
    Pattern/Repl: "test"/"test2", "test2"/"test3"
    Input box: "this is a test"
    Result: "this is a test" -> "this is a test2" -> "this is a test3"
