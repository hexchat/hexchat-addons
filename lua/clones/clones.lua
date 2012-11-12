--
-- $Id$
--
function xchat_register()
    return "clones.lua", "clones detection / scanning", "0.2"
end

function xchat_init()
    xchat.hook_server("JOIN", "handle_join")
    xchat.hook_command("CLONES", "cmd_clones", xchat.PRI_NORM, 
                                "find clones on (current) channel")
end

function cmd_clones(word, eol, data)
    local chan
    if word[2] ~= nil then
        chan = word[2]
        local ctx = xchat.find_context(nil, word[2])
        if ctx ~= nil then
            xchat.set_context(ctx)
        end
    else
        chan = xchat.get_info("channel")
    end

    local users = xchat.list_get("users")
    if users == nil or chan == nil then
        return xchat.EAT_XCHAT
    end

    local hosts = {}
    table.foreach(users,
        function(i, list)
            if list.host ~= nil then
                local host = string.find(list.host, "@", 1, true)
                if host ~= nil then
                    host = string.sub(list.host, host + 1)
                    if hosts[host] == nil then
                        hosts[host] = {list.nick}
                    else
                        table.insert(hosts[host], list.nick)
                    end
                end
            end
        end
    )
    xchat.set_context(xchat.find_context(nil, nil))
    local found = false
    table.foreach(hosts,
        function(host, list)
            if table.getn(list) > 1 then
                xchat.printf("CLONES on %s: %s (*!*@%s)", 
                        chan, table.concat(list, ", "), host)
                found = true
            end
        end
    )
    if not found then
        xchat.printf("CLONES: no clones on %s", chan)
    end
    return xchat.EAT_XCHAT
end

function parse_user(str)
    -- :Vetinari!vetinari@palace.ankh-morp.org JOIN #xchat
    local exclam = string.find(str, "!", 3, true)
    local at     = string.find(str, "@", 5, true)
    local nick   = string.sub(str,          2, exclam - 1)
    local user   = string.sub(str, exclam + 1, at - 1)
    local host   = string.sub(str,     at + 1)
    return nick, user, string.lower(host)
end

function handle_join(word, eol, data)
    local users   = xchat.list_get("users")
    local server  = xchat.get_info("server")
    if server == nil or users == nil then
        return xchat.EAT_NONE
    end

    local nick,user,host = parse_user(word[1])
    local channel = string.lower(word[3])
    if string.find(channel, ":", 1, true) == 1 then
        channel = string.sub(channel, 2)
    end
    -- hmpfz... this is the network name from server list?!
    local network = xchat.get_info("network") or "*unknown*"

    xchat.set_context(xchat.find_context(xchat.get_info("network"), channel))
    table.foreach(users,
        function(i, list) 
            if list.host ~= nil then
                local h = string.find(list.host, "@", 1, true)
                if h == nil then
                    return nil
                end
                h = string.sub(list.host, h + 1)
                if string.lower(h) == host then
                    xchat.printf("%s20CLONES on %s @ %s: %s, %s: *!*@%s", 
                            "\3", channel, network, list.nick, nick, host)
                    return true
                end
            end
        end
    )
    return xchat.EAT_NONE
end
