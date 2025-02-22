local protect = require "lib/private/protect"
local container = require "lib/private/common/container"
local Player = require "lib/private/sandbox/classes/player"
local module = {
    by_username = {}
}

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

function module.place_block(block_state, pid)
    if type(block_state.id)[1] == 's' then
        block_state.id = block.index(block_state.id)
    end

    block.place(block_state.x, block_state.y, block_state.z, block_state.id, block_state.states, pid)
end

function module.set_player_state(account_player, state)
    player.set_pos(account_player.pid, state.x, state.y, state.z)
    player.set_rot(account_player.pid, state.yaw, state.pitch, 0)
end

function module.get_player_state(account_player)
    local x, y, z = player.get_pos(account_player.pid)
    local yaw, pitch = player.get_rot(account_player.pid, true)
    return {
        x = x,
        y = y,
        z = z,
        yaw = yaw,
        pitch = pitch
    }
end

function module.set_day_time(time)
    if time == "day" then
        time = 0.5
    elseif time == "night" then
        time = 0
    elseif type(time)[1] ~= 'n' and not tonumber(time) then
        return false
    end

    time = math.normalize(tonumber(time))
    world.set_day_time(time)
    return true
end

function module.by_username.is_online(name)
    if module.get_players()[name] then
        return true
    end

    return false
end

return protect.protect_return(module)