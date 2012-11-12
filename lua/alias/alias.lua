--
-- $Id$
-- $Revision$
-- $Date$
--
local name = "alias.lua"
local desc = "Create aliases"
local version = "0.1"

local help_alias   = "Usage: /ALIAS NEWCMD COMMAND[; COMMAND2[;...]], "
                    .. "adds NEWCMD as alias for COMMAND[; COMMAND2[;...]] "
                    .. "... multiple commands are separated by ';'"
local help_unalias = "Usage: /UNALIAS NEWCMD, removes NEWCMD from aliases"
local help_aliases = "Usage: /ALIASES, shows the currently defined aliases"
aliases = {}

function xchat_register() 
    return name, desc, version
end

function xchat_init()
    xchat.hook_command("ALIAS", "cmd_alias", xchat.PRI_NORM, help_alias)
    xchat.hook_command("UNALIAS", "cmd_unalias", xchat.PRI_NORM, help_unalias)
    xchat.hook_command("ALIASES", "cmd_aliases", xchat.PRI_NORM, help_aliases)
    xchat.commandf("LOAD -e %s/alias.cfg", xchat.get_info("xchatdirfs"))
end

function xchat_unload()
    local file = io.open(
            string.format("%s/alias.cfg", xchat.get_info("xchatdirfs")), 
            "w"
        )
    if not file then
        return
    end
    table.foreach(aliases,
        function(cmd, value)
            file:write(
                string.format("ALIAS %s %s\n", 
                    cmd,  
                    string.gsub(
                            table.concat(value, "; "), "%\\%\"", "\"")
                )
            )
        end
    )
    file:flush()
    file:close()
end

function cmd_unalias(word, eol, data)
    if word[2] == nil then
        xchat.print(help_unalias)
        return xchat.EAT_XCHAT
    end
    local cmd = string.upper(word[2])
    aliases[cmd] = nil
    xchat.unhook(cmd)
    return xchat.EAT_XCHAT
end

function cmd_aliases(word, eol, data)
    xchat.printf("%-20s: %s", "Alias", "Commands");
    xchat.printf("----------------------------------------------------------------")
    table.foreach(aliases,
        function(name, cmd)
            xchat.printf("%-20s: %s", name, table.concat(cmd, "; "))
        end
    )
    return xchat.EAT_XCHAT
end

replace = {
    a = function()
        local users = {}
        local ulist = xchat.list_get("users")
        if ulist == nil then
            return ""
        end
        table.foreach(ulist,
            function(i, list)
                if list.selected > 0 then
                    table.insert(users, list.nick)
                end
            end
        )
        return table.concat(users, " ")
    end,
    c = function()
        local chan = xchat.get_info("channel") or ""
        return chan
    end,
    e = function()
        local net = xchat.get_info("network") or ""
        return net
    end,
    n = function() 
        local nick = xchat.get_info("nick") or ""
        return nick
    end,
    t = function()
        return os.date()
    end,
    v = function() 
        local version = xchat.get_info("version") or ""
        return version
    end,
}


function cmd_alias(word, eol, data)
    if word[2] == nil or word[3] == nil then
        xchat.print(help_alias)
        return xchat.EAT_XCHAT
    end
    local new_cmd = string.upper(word[2])
    -- ok, now we have at least a new command name (word[2]) and a command 
    -- (eol[3])...
    local subcmd = {}
    local start  = 1
    local matchall = string.gfind
    if matchall == nil then -- lua 5.0 / 5.1 compat ...
        matchall = string.gmatch
    end
    for cmd in matchall(eol[3], "([^%;]+)") do
        cmd = string.gsub(cmd, "^%s+(.*)$", "%1")
        table.insert(subcmd, cmd)
    end
    local eval = string.format(
"function alias_%s(word, eol, data)\
  local r = replace\
  table.foreach(data,\
     function(i, cmd)\
         cmd = string.gsub(cmd, \"%%%%(%%d+)\", function (v)\
                         return word[tonumber(v)]\
                    end\
              )\
         cmd = string.gsub(cmd, \"%%&(%%d+)\", function (v) \
                        return eol[tonumber(v)]\
                    end\
             )\
         cmd = string.gsub(cmd, \"%%%%(%w)\", function (v) \
                        if type(r[v] == \"function\" then\
                            return r[v]()\
                        else\
                            return \"%%\"..v
                        end\
                    end\
            )\
         xchat.command(cmd)\
     end\
  )\
  return xchat.EAT_ALL\
end\n", new_cmd)
    assert(loadstring(eval, string.format("alias_%s", new_cmd)))()
    xchat.hook_command(new_cmd, string.format("alias_%s", new_cmd), 
                        xchat.PRI_NORM,nil, subcmd)
    aliases[new_cmd] = subcmd
    return xchat.EAT_XCHAT
end
