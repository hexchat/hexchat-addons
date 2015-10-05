hexchat.register("debbugs.lua", "0.1", "Show debian bugs on right click")

local logo = "/usr/share/pixmaps/debian-logo-16x16.png"

local function unload()
	hexchat.command("MENU DEL \"$CHAN/Debian Bug #\"")
end

local function cmd_debbug(word, eol, data)
	local bug = word[2]:match"#(%d+)$"
	if bug then
		hexchat.command("URL http://bugs.debian.org/" .. tonumber(bug))
	end
	return hexchat.EAT_HEXCHAT
end

hexchat.hook_unload(unload)
hexchat.hook_command("DEBBUG", cmd_debbug)
hexchat.command("MENU -i" .. logo .. " ADD \"$CHAN/Debian Bug #\" \"DEBBUG %s\"")
