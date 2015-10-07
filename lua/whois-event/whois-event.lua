local name = "whois.lua"
local desc = "Vetinari's whois.lua"
-- AKA: print the whois info to the tab/window where it was called and not
--	  to the server tab/window...
local version = "0.4"

hexchat.register(name, version, desc)

pending = {}

local function cmd_whois(word, eol)
	local nick = word[2]
	local target = word[3]
	if not target then
		target = nick
	end
	table.insert(pending,
			{
				nick = nick, 
				server = hexchat.get_info"server",
				ctx = hexchat.get_context()
			}
		)
	hexchat.command(("QUOTE WHOIS %s %s"):format(nick, target))
	return hexchat.EAT_ALL
end

local function pending_ctx(nick, server)
	for _, item in ipairs(pending) do
		if hexchat.nickcmp(item.nick, nick) == 0 and hexchat.nickcmp(item.server, server) == 0 then
			return item.ctx
		end
	end
end

local inside = false
local function handle_whois(event, word)
	if inside then
		return hexchat.EAT_NONE
	end
	local ctx = pending_ctx(word[1], hexchat.get_info"server")
	if not ctx then
		return hexchat.EAT_NONE
	end
	inside = true
	ctx:emit_print(event, (unpack or table.unpack)(word))
	inside = false
	if event == "WhoIs End" then
		local j = 0
		for i, v in ipairs(pending) do
			if v.ctx == ctx then
				j = i
				break
			end
		end
		table.remove(pending, j)
	end
	return hexchat.EAT_HEXCHAT
end

hexchat.hook_command("WHOIS", cmd_whois)
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
for _, event in pairs(events) do
	hexchat.hook_print(event, function(word)return handle_whois(event, word) end)
end

