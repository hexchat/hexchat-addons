--
-- $Id$
--
-- requires xchat cvs version from 2007-05-20 (or later) 
--
function xchat_register()
    return "debbugs.lua", "Show debian bugs on right click", "0.1"
end

function xchat_init()
    xchat.hook_command("DEBBUG", "cmd_debbug")
    local logo = "/usr/share/pixmaps/debian-logo-16x16.png"
    xchat.commandf("MENU -i%s ADD \"$CHAN/Debian Bug #\" \"DEBBUG %%s\"", logo)
end

function xchat_unload()
    xchat.command("MENU DEL \"$CHAN/Debian Bug #\"")
end

function cmd_debbug(word, eol, data)
    local bug = word[2]
    if string.find(bug, "#", 1, true) == 1 then
        bug = string.sub(bug, 2)
    end
    if string.find(bug, "^%d+$") then
        xchat.commandf(
            "EXEC /usr/bin/x-www-browser http://bugs.debian.org/%d", 
                tonumber(bug)
        )
    else
        xchat.printf("DEBBUG: bug number '%s' contains non digits...", bug)
    end
    return xchat.EAT_XCHAT
end
