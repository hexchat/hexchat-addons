hexchat.register("input-r-search.lua", "0.1", "reverse search input line with Ctrl-R")

if not hexchat.pluginprefs.size then
	hexchat.pluginprefs.size = 1000
end
if not hexchat.pluginprefs.file then
	hexchat.pluginprefs.file = hexchat.get_info"configdir" .. "/history.txt"
end

local running = false
local search = ""
local history = {}
local match = nil

local function unload()
	local file = io.open(hexchat.pluginprefs.file, "w")
	if file then
		for _, line in ipairs(history) do
			file:write(line .. "\n")
		end
		file:close()
	end
end

local function print_setting(name)
	local key = "input_hist_" .. name
	hexchat.print(key .. "\00302" .. ("."):rep(29 - #key) .. "\00303:\015 " .. hexchat.pluginprefs[name])
end

local function cmd_set(word, eol)
	if not word[3] then
		if not word[2] then
			print_setting"size"
			print_setting"file"
		else
			local pat = word[2]:gsub("%p", function(p)
				if p == "?" then
					return "."
				elseif p == "*" then
					return ".*"
				else
					return "%" .. p
				end
			end)
			pat = "^" .. pat .. "$"
			for k, v in pairs(hexchat.pluginprefs) do
				if ("input_hist_" .. k):match(pat) then
						print_setting(k)
				end
			end
		end
	else
		local key = word[2]:gsub("^input_hist_", "")
		if hexchat.pluginprefs[key] then
			hexchat.pluginprefs[key] = tonumber(word[3]) or word[3]
			return hexchat.EAT_HEXCHAT
		end
	end
	return hexchat.EAT_NONE
end

function check_key(word)
	local key_value = tonumber(word[1])

	if key_value == 65307 or (key_value == 99 and math.floor(word[2] / 4) % 2 == 1) then -- <Esc>, <C-C>
		if not running then
			return hexchat.EAT_NONE
		end
		if match == nil then
			match = ""
		end
		hexchat.command("settext " .. match)
		hexchat.command("setcursor " .. #match)
		search = ""
		match = nil
		running = false

	elseif key_value == 65293 or key_value == 65421 then -- <Enter>, <KP_Enter>
		local ret
		if running then
			local txt
			if match == nil then
				txt = search
				ret = hexchat.EAT_XCHAT
			else
				txt = match
				ret = hexchat.EAT_NONE
			end
			hexchat.command("settext " .. txt)
			hexchat.command("setcursor " .. #txt)
			table.insert(history, 1, hexchat.get_info"inputbox")
			search = ""
			running = false
			match = nil
		else
			table.insert(history, 1, hexchat.get_info"inputbox")
			ret = hexchat.EAT_NONE
		end
		for i = hexchat.pluginprefs.size, #history do
			history[i] = nil
		end
		return ret

	elseif key_value == 114 and math.floor(word[2] / 4) % 2 == 1 then -- <C-R>
		hexchat.command"settext (Ctrl-R-Search) `':"
		hexchat.command"setcursor 17"
		running = true

	else
		if not running then
			return hexchat.EAT_NONE
		end
		if tonumber(word[4]) ~= 0 or key_value == 65288 then -- key or <Esc>
			if key_value == 65288 then
				search = search:sub(1, -2)
			else
				search = search .. word[3] or ""
			end
			match = nil
			for _, line in pairs(history) do
				if line:find(search, 1, true) then
					match = line
					break
				end
			end
			if match == nil then
				hexchat.command("settext " .. search)
				hexchat.command("setcursor " .. #search)
				running = false
				search = ""
			else
				hexchat.command("settext (Ctrl-R-Search) `" .. search .. "': " .. match)
				hexchat.command("setcursor " .. (17 + #search))
			end
			return hexchat.EAT_HEXCHAT
		end
	end
	return hexchat.EAT_NONE
end

local file = io.open(hexchat.pluginprefs.file, "r")
if file then
	for line in file:lines() do
		table.insert(history, line)
	end
	file:close()
end

hexchat.hook_unload(unload)
hexchat.hook_print("Key Press", check_key)
hexchat.hook_command("SET", cmd_set)
