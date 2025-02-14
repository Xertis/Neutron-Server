local protect = require "lib/private/protect"
local container = require "lib/private/common/container"
local Player = require "lib/private/sandbox/classes/player"
local module = {}

container.put("players_online", nil, 0)

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

    container.put("players_online", account_player)
    return account_player
end

function module.leave_player(account_player)
    account_player:abort()

    logger.log(string.format('Player "%s" is leave.', account_player.username))

    for indx, player in ipairs(container.get_all("players_online")) do
        local name = player.username

        if name == account_player.username then
            container.put("players_online", nil, indx)
        end
    end
    return account_player
end

function module.get_players()
    local players_data = container.get_all("players_online")
    local players = {}

    for _, player in ipairs(players_data) do
        players[player.username] = player
    end

    return players
end

function module.get_player(account)
    return container.get_all(account.username)[1]
end

function module.get_chunk(pos)
    return world.get_chunk_data(pos.x, pos.z)
end

function module.place_block(_block, pid)
    block.place(_block.x, _block.y, _block.z, _block.id, _block.states, pid)
end

function module.set_player_state(account_player, state)
    player.set_pos(account_player.pid, state.x, state.y, state.z)
end

function module.get_player_state(account_player)
    local x, y, z = player.get_pos(account_player.pid)
    return {
        x = x,
        y = y,
        z = z
    }
end

return protect.protect_return(module)