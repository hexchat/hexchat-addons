--
-- $Id$
-- $Revision$
-- $Date$
--
local name = "match.lua"
local desc = "do pattern matching on user@host, nick, ..."
local version = "0.2"

function xchat_register()
    return name, desc, version
end

function xchat_init()
    local help = "MATCH: Usage: MATCH [-l] PATTERN"
    -- -l: pattern is lua pattern, not default irc pattern
    xchat.hook_command("MATCH", "cmd_match", xchat.PRI_NORM, help)
end

function irc2lua(str)
    str = string.gsub(str, "%?", "\0")
    str = string.gsub(str, "%%", "%%%%")
    str = string.gsub(str, "%.", "%%.")
    str = string.gsub(str, "%*", ".*")
    str = string.gsub(str, "%z", ".")
    str = string.gsub(str, "([^%w%%.*])", "%%%1")
    return str
end

function cmd_match(word, eol, data)
    local pattern, opattern
    local matches = {}
    if string.find(word[2], "^%-") and string.find(word[2], "l") then
        opattern = word[3]
        pattern  = word[3]
    else
        opattern = word[2]
        pattern  = irc2lua(word[2])
    end

    local users   = xchat.list_get("users")
    if users == nil then
        xchat.print("MATCH: not on a channel?")
        return xchat.EAT_XCHAT
    end

    table.foreach(users,
        function(i, list)
            if string.find(list.nick, pattern) 
                or
               string.find(list.host, pattern)
            then
                table.insert(matches, { list.nick, list.host })
            end
        end
    )

    if table.getn(matches) == 0 then
        xchat.printf("MATCH: no matches for '%s'", opattern)
    else
        xchat.printf("------------ matches for '%s' ---------------", opattern)
        table.foreach(matches,
            function(i, list)
                xchat.printf("%-15s %s!%s", list[1], list[1], list[2])
            end
        )
    end
    return xchat.EAT_XCHAT
end

-- END
