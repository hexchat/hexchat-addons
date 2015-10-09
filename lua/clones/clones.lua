hexchat.register("clones.lua", "0.2", "clones detection / scanning")

local function cmd_clones(word, eol)
	local ctx
	local chan
	if word[2] then
		chan = word[2]
		ctx = hexchat.find_context(nil, word[2])
		if not ctx then
			hexchat.print("No channel named '" .. chan .. "'")
			return hexchat.EAT_ALL
		end
	else
		chan = hexchat.get_info"channel"
		ctx = hexchat.get_context()
	end

	local hosts = {}
	for user in ctx:iterate"users" do
		if user.host then
			local host = user.host:match"@(.*)"
			if host then
				host = host:lower()
				if not hosts[host] then
					hosts[host] = {}
				end
				table.insert(hosts[host], user.nick)
			end
		end
	end

	local found = false

	for host, nicks in pairs(hosts) do
		if #nicks > 1 then
			hexchat.print("CLONES on " .. chan .. ": " .. table.concat(nicks, ", ") .. " (*!*@" .. host .. ")")
			found = true
		end
	end
	if not found then
		hexchat.print("CLONES: no clones on " .. chan)
	end
	return hexchat.EAT_ALL
end

local function parse_user(str)
	-- :Vetinari!vetinari@palace.ankh-morp.org JOIN #hexchat
	local nick, user, host = str:match"^:([^!]*)!([^@]*)@(.*)$"
	return nick, user, host:lower()
end

local function handle_join(word, eol)
	local nick, user, host = parse_user(word[1])
	local channel = word[3]:gsub("^:", "")
	local network = hexchat.get_info"network" or "*unknown*"

	local server = hexchat.get_info"server"
	for user in hexchat.iterate"users" do
		if user.host then
			local h = user.host:match"@(.*)"
			if h and h:lower() == host then
				hexchat.find_context(nil, nil):print("\00320CLONES on " .. channel .. " @ " .. network .. ": " .. user.nick .. ", " .. nick .. " (*!*@" .. host .. ")")
			end
		end
	end
	return hexchat.EAT_NONE
end

hexchat.hook_server("JOIN", handle_join)
hexchat.hook_command("CLONES", cmd_clones, "find clones on (current) channel")
