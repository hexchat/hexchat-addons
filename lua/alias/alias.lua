local name = "alias.lua"
local desc = "Create aliases"
local version = "0.1"

hexchat.register(name, version, desc)

local help_alias = "Usage: /ALIAS NEWCMD COMMAND[; COMMAND2[;...]], adds NEWCMD as alias for COMMAND[; COMMAND2[;...]] ... multiple commands are separated by ';'"
local help_unalias = "Usage: /UNALIAS NEWCMD, removes NEWCMD from aliases"
local help_aliases = "Usage: /ALIASES, shows the currently defined aliases"

local hooks = {}

local function cmd_unalias(word, eol)
	if not word[2] then
		hexchat.print(help_unalias)
		return hexchat.EAT_HEXCHAT
	end
	local name = word[2]:upper()
	if hooks[name] then
		hooks[name]:unhook()
		hooks[name] = nil
		hexchat.pluginprefs[name] = nil
	end
	return hexchat.EAT_HEXCHAT
end

local function cmd_aliases(word, eol)
	hexchat.print(("%-20s: %s"):format("Alias", "Commands"))
	hexchat.print("----------------------------------------------------------------")
	for name, cmd in pairs(hexchat.pluginprefs) do
		hexchat.print(("%-20s: %s"):format(name, cmd))
	end
	return hexchat.EAT_HEXCHAT
end

local function hook(name, cmd)
	local function callback(word, eol)
		for subcmd in cmd:gmatch"%s*([^;%s][^;]*)" do
			subcmd = subcmd:gsub("%%(%w)", function(v)
				if v == "a" then
					local users = {}
					for user in hexchat.iterate"users" do
						if user.selected > 0 then
							table.insert(users, user.nick)
						end
					end
					return table.concat(users, " ")
				elseif v == "c" then
					return hexchat.get_info"channel" or ""
				elseif v == "e" then
					return hexchat.get_info"network" or ""
				elseif v == "n" then
					return hexchat.get_info"nick" or ""
				elseif v == "t" then
					return os.date()
				elseif v == "v" then
					return hexchat.get_info"version" or ""
				end
			end)
			subcmd = subcmd:gsub("%%(&?)(%d+)", function(a, v)
				if a == "&" and tonumber(v) then
					return eol[tonumber(v) + 1] or ""
				elseif a == "" and tonumber(v) then
					return word[tonumber(v) + 1] or ""
				end
			end)
			hexchat.command(subcmd)
		end
		return hexchat.EAT_ALL
	end
	if hooks[name] then
		hooks[name]:unhook()
	end
	hooks[name] = hexchat.hook_command(name, callback)
	hexchat.pluginprefs[name] = cmd
end

local function cmd_alias(word, eol)
	if word[2] == nil or word[3] == nil then
		hexchat.print(help_alias)
		return hexchat.EAT_HEXCHAT
	end
	local name = word[2]:upper()
	local cmd = eol[3]
	hook(name, cmd)
	return hexchat.EAT_HEXCHAT
end

for k, v in pairs(hexchat.pluginprefs) do
	hook(k, v)
end

hexchat.hook_command("ALIAS", cmd_alias, help_alias)
hexchat.hook_command("UNALIAS", cmd_unalias, help_unalias)
hexchat.hook_command("ALIASES", cmd_aliases, help_aliases)

