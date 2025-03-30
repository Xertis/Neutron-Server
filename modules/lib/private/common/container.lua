local protect = require "lib/private/protect"
if protect.protect_require() then return end

local module = {
    player_online = {},
    clients_all = {},
    accounts = {},
}
local DATA = {
    player_online = {},
    clients_all = {},
    accounts = {},
}

function module.accounts.put(username, account)
    print(debug.traceback())
    print("PUT", username, json.tostring(account))
    DATA.accounts[username] = account
end

function module.player_online.put(username, player)
    DATA.player_online[username] = player
end

function module.clients_all.set(clients)
    DATA.clients_all = clients
end

function module.accounts.get(username)
    if username then
        return DATA.accounts[username]
    else
        return DATA.accounts
    end
end

function module.player_online.get(username)
    if username then
        return DATA.player_online[username]
    else
        return DATA.player_online
    end
end

function module.clients_all.get()
    return DATA.clients_all
end

return module