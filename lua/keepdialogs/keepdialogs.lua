-- SPDX-License-Identifier: MIT
hexchat.register('KeepDialogs', '1', "Saves current dialogs for next start")

-- On successful connection restore dialogs
hexchat.hook_server('376', function (word, word_eol)
    local network = hexchat.get_info('network')
    if network then
        local dialogs = hexchat.pluginprefs['dialogs_' .. network]
        if dialogs then
            hexchat.print('KeepDialogs: restoring dialogs for network ' .. network)
            for user in string.gmatch(dialogs, '[^,]+') do
                hexchat.command('query -nofocus ' .. user)
            end
        end
    end
end)

-- On unload save dialogs
hexchat.hook_unload(function ()
    local dialogs = {}
    for chan in hexchat.iterate('channels') do
        if not dialogs[chan.network] then
            dialogs[chan.network] = {}
        end
        if chan.type == 1 then
            chan.context:print('KeepDialogs: saving dialogs for network ' .. chan.network)
        elseif chan.type == 3 then
            table.insert(dialogs[chan.network], chan.channel)
        end
    end
    for network, users in pairs(dialogs) do
        hexchat.pluginprefs['dialogs_' .. network] = table.concat(users, ',')
    end
end)
