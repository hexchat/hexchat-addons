# Floodcontrol

Controls flooding.

HexChat plugin for intercepting floody messages from the user, and redirecting them to a pastebin service.

## Inputbox replacement
Messages can be replaced while they are still in the user's inputbox.

Some examples:

```
long message in inputbox
```
Might get replaced with:
```
https://example.pastebin/abcde
```
-------
It also knows about messages sent with commands. So:
```
/msg Burrito long message in inputbox
```
Might get replaced with:
```
/msg Burrito https://example.pastebin/abcd
```

These replacements happen automatically if the user tries to send a message which is over a line limit, after pressing Enter again when notified. This line limit is currently hardcoded at 2 lines by ```get_max_lines```. The notification looks like this:
> **[Floodcontrol]**  That message looks like a flood (11 lines). To really send it, press **Alt+Enter**. To send it through a pastebin, press **Enter** again.

To turn the autopaste functionality off, use the command ```/fc_autopaste off```. To turn it back on, ```/fc_autopaste on```. Providing no on/off parameter will toggle the setting.

## Pastebin from a command

This is the most versatile way of interacting with Floodcontrol. You can bind a command to a Userlist button (*Settings* > *Userlist Buttons...*), for example.
```
usage: fc_paste [-h] [-fi] [-fb] [-fw] [-C] [-p SERVICE] [-n NAME] [-e EXPIRY]
                [-s SYNTAX] [-x EXPOSURE] [-tc COMMAND] [-ti]
                [-tir] [-tb] [-S] [--guard-inputbox-cmd]
                [content [content ...]]

optional arguments:
  -h, --help            show this help message and exit
  --guard-inputbox-cmd  If specified, will take care not to send known
                        commands to the pastebin, and preserve it when we get
                        the URL back. For instance, "/msg Burrito testing" would
                        only send "testing" and preserve "/msg Burrito" in the 
                        inputbox.

Input sources:
  content               Ignored if a --from-* argument is specified. The
                        content we should send to the pastebin. Not reliable
                        when running the command from HexChat's inputbox
                        because of how line breaks behave. Use a --from-*
                        argument instead.
  -fi, --from-inputbox  If specified, will retrieve HexChat inputbox contents
                        and send it to the pastebin.
  -fb, --from-clipboard
                        If specified, will retrieve clipboard and send it to
                        the pastebin.
  -fw, --from-window    If specified, will create a popup window using /GETSTR
                        and send the response to the pastebin.
  -C, --confirm         If specified, we will first use /GETBOOL to get user
                        confirmation before sending data to the patebin
                        service.

Pastebin API arguments:
  -p SERVICE, --service SERVICE
                        The name of the pastebin API desired.
  -n NAME, --name NAME  The name of your paste.
  -e EXPIRY, --expiry EXPIRY
                        Length of time we should tell the pastebin API to keep
                        the paste.
  -s SYNTAX, --syntax SYNTAX
                        Try to get the pastebin to use syntax highlighting,
                        e.g. 'python' or 'html'
  -x EXPOSURE, --exposure EXPOSURE
                        Privacy setting for this paste.

Output destinations:
  -tc COMMAND, --to-command COMMAND
                        The command that should be ran with the result, e.g.
                        '--to-command "/msg OtherPerson" content goes here'
                        will send the Pastebin URL as '/msg OtherPerson
                        http://example.com/abcd'.
  -ti, --to-inputbox    If specified, will add the pastebin URL to HexChat's
                        inputbox at the current cursor position.
  -tir, --to-inputbox-replace
                        If specified, will set HexChat's inputbox to the
                        pastebin URL.
  -tb, --to-clipboard   If specified, will add the pastebin URL to the
                        clipboard.
  -S, --say             If specified, will output pastebin URL to current
                        window. Same as '--to-command say'
```
### Examples

Probably the easiest: appends the current inputbox content with a Pastebin URL after sending the Pastebin service the contents of my clipboard.
Think: "from board, to inputbox"
```
/fc_paste -fb -ti
```

You can have multiple "--to-*" arguments. Think: "from board, to inputbox, and to board"
```
/fc_paste -fb -ti -tb
```

## Roadmap

The code is messy (needs to be grouped), and functions have crap names. But it's usable. 

After cleaning up and refining existing functionality, I want to also add features for reading Pastebins inside HexChat, so that a user could type "/fc_read" and the last recognised Pastebin URL in the channel would be retrieved and shown to the user (either in a launched browser, or a few lines inside the HexChat window, or something like that).

## Scripts with related functionality

* adds a `/paste` command and uses fedora's pastebin: https://gist.github.com/TingPing/5993eeb9019f8b0798ad270f365dd6a4
