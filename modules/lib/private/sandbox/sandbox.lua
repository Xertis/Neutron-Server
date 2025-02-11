local protect = require "lib/private/protect"
local container = require "lib/private/common/container"
local Player = require "lib/private/sandbox/classes/player"
local module = {}

function module.join_player(client)
    local client_player = container.get_all(client.username)[1] or Player.new(client.username)

    local status = client_player:revive()

    if status == CODES.players.ReviveSuccess or status == CODES.players.WithoutChanges then
        -- Ну мы его разбудили правильно, ничего делать не надо, мы молодцы
    elseif status == CODES.players.DataLoss then
        client_player:set("pid", player.create(client_player.username))
        client_player:set("entity_id", player.get_entity(client_player.pid))
        
        client:set("world", CONFIG.game.main_world)
        client_player:set("active", true)
    end

    if client_player:is_active() then
        container.put(client_player.username, client_player, 1)
    end

    logger.log(string.format('Player "%s" is join.', client_player.username))
    client_player:save()

    return client_player
end

return protect.protect_return(module)