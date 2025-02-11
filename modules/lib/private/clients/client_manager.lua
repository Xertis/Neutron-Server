local protect = require "lib/private/protect"
if protect.protect_require() then return end

local Client = require "lib/private/clients/client"
local container = require "lib/private/common/container"
local module = {}

function module.login(username, password)
    logger.log(string.format('Client "%s" is logging...', username))

    local client = Client.new(username, password) or container.get_all(username).client
    local status = client:revive()

    if status == CODES.clients.ReviveSuccess or status == CODES.clients.WithoutChanges then
        -- Ну мы его разбудили правильно, ничего делать не надо, мы молодцы
    elseif status == CODES.clients.WrongPassword then
        logger.log(string.format('Client "%s" entered an incorrect password.', client.username))
        return
    elseif status == CODES.clients.DataLoss then
        client:set("role", CONFIG.roles.default_role)
        client:set("active", true)
    end

    if client:is_active() and container.get_all(client.username).client == nil then
        container.put(client.username, client, "client")
    end

    client:save()

    return client
end

return module