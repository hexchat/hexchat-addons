local name = "match.lua"
local desc = "do pattern matching on user@host, nick, ..."
local version = "0.2"

hexchat.register(name, version, desc)

local function irc2lua(str)
	return str:gsub("%p", function(p)
		if p == "?" then
			return "."
		elseif p == "*" then
			return ".*"
		else
			return "%" .. p
		end
	end)
end

local function cmd_match(word, eol)
	local pattern
	local lua
	if word[2] == "-l" then
		pattern = word[3]
		lua = true
	else
		pattern = word[2]
		lua = false
	end

	local matches = {}
	for user in hexchat.iterate"users" do
		local pat = pattern
		if not lua then
			pat = irc2lua(pat)
		end
		if user.nick:find(pat) or (user.host or ""):find(pat) then
			table.insert(matches, {user.nick, user.host or ""})
		end
	end
	if #matches == 0 then
		hexchat.print("MATCH: no matches for '" .. pattern .. "'")
	else
		hexchat.print("------------ matches for '" .. pattern .. "' ---------------")
		for _, m in ipairs(matches) do
			hexchat.print(("%-15s %s!%s"):format(m[1], m[1], m[2]))
		end
	end
	return hexchat.EAT_ALL
end

local help = "MATCH: Usage: MATCH [-l] PATTERN"

hexchat.hook_command("MATCH", cmd_match, help)
