--
-- $Id$
-- $Revision$
-- $Date$
--
local name = "whois.lua"
local desc = "Vetinari's whois.lua"
-- AKA: print the whois info to the tab/window where it was called and not
--      to the server tab/window...
local version = "0.4"

pending = {}
request = {}

function xchat_register() 
    return name, desc, version
end

function xchat_init()
    xchat.hook_command("WHOIS", "cmd_whois")
    local events = {
        "WhoIs Authenticated",
        "WhoIs Away Line",
        "WhoIs Channel/Oper Line",
        "WhoIs End",
        "WhoIs Identified",
        "WhoIs Idle Line with Signon",
        "WhoIs Idle Line",
        "WhoIs Name Line",
        "WhoIs Real Host",
        "WhoIs Server Line",
        "WhoIs Special",
    }
    table.foreach(events,
        function(i, event)
            xchat.hook_print(event, "handle_whois")
        end
    )
end

function cmd_whois(word, word_eol, data)
    local nick   = word[2]
    local target = word[3]
    if target == nil then
        target = nick
    end
    table.insert(pending, 
            { 
              ["nick"]   = nick, 
              ["server"] = xchat.get_info("server"),
              ["ctx"]    = xchat.get_context()
            } 
        )
    xchat.command(string.format("QUOTE WHOIS %s %s", nick, target))
    return xchat.EAT_ALL
end

function pending_ctx(nick, server)
    return table.foreach(pending, 
        function(i, list) 
            if xchat.nickcmp(list.nick, nick) == 0
               and 
               xchat.nickcmp(list.server, server) == 0 
            then
                return list.ctx
            end
        end
    )
end

function context_set(nick)
    local server = xchat.get_info("server") 
    local ctx    = pending_ctx(nick, server)
    if ctx ~= nil then
        xchat.set_context(ctx)
    end
    return ctx
end

function handle_whois(word, data)
    if not context_set(word[1]) then
        return xchat.EAT_NONE
    end
    local event = xchat.event()
    xchat.unhook(event)
    xchat.emit_print(event, unpack(word))
    xchat.hook_print(event, "handle_whois")
    if event == "WhoIs End" then
        local i = table.foreach(pending, 
            function(n, list) 
                if list.ctx == ctx then
                    return n
              end
            end
        )
        table.remove(pending, i)
    end
    return xchat.EAT_XCHAT
end

-- vim: ts=4 sw=4 expandtab syn=lua
