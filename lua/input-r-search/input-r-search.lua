--
-- $Id$
-- $Revision$
-- $Date$
--

-- defaults:
config = {}
config["size"] = 1000
config["file"] = string.format("%s/history.txt", xchat.get_info("xchatdirfs"))

-- 
running = false
-- history = {"/unload ./input-r-search.lua", "/load ./input-r-search.lua"}
search  = {}
history = {}
match   = nil

function xchat_register()
    return "input-r-search.lua", "reverse search input line with Ctrl-R", "0.1"
end

function xchat_init()
    local cfg  = string.format("%s/history.cfg", xchat.get_info("xchatdirfs"))
    local ok, err = pcall(dofile, cfg)
    if not ok then
        xchat.printf("error loading %s: %s", cfg, err)
    end
    if input_hist_file == nil then
        input_hist_file = config["file"]
    else
        config["file"] = input_hist_file
    end
    if input_hist_size == nil then
        input_hist_size = tonumber(config["size"])
    else
        input_hist_size = tonumber(input_hist_size)
        config["size"] = input_hist_size
    end

    local file = io.open(input_hist_file, "r")
    if file then
        local line = file:read("*l")
        while line do
            table.insert(history, line);        
            line = file:read("*l")
        end
        file:close()
    end
    xchat.hook_print("Key Press", "check_key")
    xchat.hook_command("SET", "cmd_set")
end

function xchat_unload()
    local file = io.open(input_hist_file, "w")
    pcall(os.execute, 
        string.format("chmod 600 %s", 
            string.gsub(input_hist_file, "([^%w/.%-])", "\\%1")
        )
    )
    if file then
        table.foreach(history,
            function(i, line)
                file:write(string.format("%s\n", line))
            end
        )
        file:flush()
        file:close()
    end
    local cfg = string.format("%s/history.cfg", xchat.get_info("xchatdirfs"))
    file = io.open(cfg, "w")
    if file then
        table.foreach(config,
            function(key, val)
                file:write(string.format("input_hist_%s = \"%s\"\n", key, tostring(val)))
            end
        )
        file:flush()
        file:close()
    end
end

function print_settings(names)
    table.foreach(names,
        function(i, name)
            xchat.printf("input_hist_%s..............19: %s", 
                                                        name, config[name])
        end
    )
end

function cmd_set(word, eol, data)
    if word[3] == nil then
        if word[2] == nil then
            print_settings({"size", "file"})
        else
            if string.find(word[2], "*", 1, true) then
                local pat = string.gsub(word[2], "%*", ".*")
                table.foreach(config,
                    function(key, val) 
                        if string.find(string.format("input_hist_%s", key), pat)
                        then
                            print_settings({key})
                        end
                    end
                )
            end
        end
    else
        local key = string.gsub(word[2], "^input_hist_", "")
        if config[key] ~= nil then
            config[key] = word[3]
            input_hist_file = config["file"]
            input_hist_size = tonumber(config["size"])
            return xchat.EAT_XCHAT
        end
    end
    return xchat.EAT_NONE
end

function check_key(word, data)
    local key_value = tonumber(word[1])

    if key_value == 65307 then -- <Esc>
        if not running then
            return xchat.EAT_NONE
        end
        if match == nil then
            match = ""
        end
        xchat.commandf("settext %s", match)
        xchat.commandf("setcursor %d", string.len(match))
        search  = {}
        match   = nil
        running = false

    elseif key_value == 65293 or key_value == 65421 then -- <Enter>, <KP_Enter>
        local ret 
        if running then
            local txt
            if match == nil then
                txt = table.concat(search, "")
                ret = xchat.EAT_XCHAT
            else
                txt = match
                ret = xchat.EAT_NONE
            end
            xchat.commandf("settext %s", txt)
            xchat.commandf("setcursor %d", string.len(txt))
            table.insert(history, 1, xchat.get_info("inputbox"))
            search  = {}
            running = false
            match   = nil
        else
            table.insert(history, 1, xchat.get_info("inputbox"))
            ret = xchat.EAT_NONE
        end
        local hist_size = table.getn(history)
        if hist_size > input_hist_size then
            for i=input_hist_size, hist_size do
                table.remove(history)
            end
        end
        return ret

    elseif key_value == 114 and xchat.bits(word[2])[3] then -- Ctrl-R was pressed
        -- xchat.print("Ctrl-R pressed")
        xchat.command("settext (Ctrl-R-Search) `':")
        xchat.command("setcursor 17")
        running = true

    else
        if not running then
            return xchat.EAT_NONE
        end
        if word[4] ~= 0 then
            table.insert(search, word[3] or "")
        end
        local str   = table.concat(search, "")
        match = table.foreach(history,
            function(i, line)
                if string.find(line, str, 1, true) then
                    -- xchat.printf("hist: %d: %s <=> %s", i, str, line)
                    return line
                end
            end
        )
        if match == nil then
            xchat.commandf("settext %s", str)
            xchat.commandf("setcursor %d", string.len(str))
            running = false
            search  = {}
        else
            xchat.commandf("settext (Ctrl-R-Search) `%s': %s", str, match)
            xchat.commandf("setcursor %d", 17 + string.len(str))
        end
        return xchat.EAT_XCHAT
    end
    return xchat.EAT_NONE
end
