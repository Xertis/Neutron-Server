local protect = require "lib/private/protect"
local container = require "lib/private/common/container"
local Player = require "lib/private/sandbox/classes/player"
local module = {}

function module.join_player(account)
    local account_player = container.get_all(account.username)[1] or Player.new(account.username)

    local status = account_player:revive()

    if status == CODES.players.ReviveSuccess or status == CODES.players.WithoutChanges then
        -- Ну мы его разбудили правильно, ничего делать не надо, мы молодцы
    elseif status == CODES.players.DataLoss then
        account_player:set("pid", player.create(account_player.username))
        account_player:set("entity_id", player.get_entity(account_player.pid))

        account:set("world", CONFIG.game.main_world)
        account_player:set("active", true)
    end

    if account_player:is_active() then
        container.put(account_player.username, account_player, 1)
    end

    logger.log(string.format('Player "%s" is join.', account_player.username))
    account_player:save()

    return account_player
end

function module.get_chunk(pos)
    return world.get_chunk_data(pos.x, pos.z)
end

function module.place_block(_block, pid)
    block.place(_block.x, _block.y, _block.z, _block.id, _block.states, pid)
    print(_block.x, _block.y, _block.z, _block.id, _block.states)
end

return protect.protect_return(module)