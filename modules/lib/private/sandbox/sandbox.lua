local protect = require "lib/private/protect"
local container = require "lib/private/common/container"
local Player = require "lib/private/sandbox/classes/player"
local metadata = require "lib/private/files/metadata"
local module = {
    by_username = {},
    by_invid = {}
}

function module.join_player(account)
    local account_player = container.player_online.get(account.username) or Player.new(account.username)

    local status = account_player:revive()

    if status == CODES.players.ReviveSuccess or status == CODES.players.WithoutChanges then
        -- Ну мы его разбудили правильно, ничего делать не надо, мы молодцы
    elseif status == CODES.players.DataLoss then
        local pid = player.create(account_player.username, table.count_pairs(metadata.players.get_all())+1)
        logger.log(string.format('Player "%s" has been created with pid: %s', account.username, pid))
        account_player:set("pid", pid)
        account_player:set("entity_id", player.get_entity(account_player.pid))

        local y = 0
        local block_id = block.get(0, y, 0)
        while block_id ~= 0 and block_id ~= -1 do
            y = y + 1
            block_id = block.get(0, y, 0)
        end

        player.set_pos(account_player.pid, 0, y+1, 0)
        player.set_spawnpoint(account_player.pid, 0, y+1, 0)
        account_player:set("world", CONFIG.game.main_world)
        account_player:set("active", true)

        local invid, _ = player.get_inventory(account_player.pid)
        account_player:set("invid", invid)
    end

    if account_player:is_active() then
        container.player_online.put(account_player.username, account_player)
    end

    logger.log(string.format('Player "%s" is join.', account_player.username))
    account_player:save()

    if player.is_suspended(account_player.pid) then
        player.set_suspended(account_player.pid, false)
    end

    return account_player
end

function module.leave_player(account_player)
    account_player:abort()

    logger.log(string.format('Player "%s" is leave.', account_player.username))

    container.player_online.put(account_player.username, nil)

    player.set_suspended(account_player.pid, true)

    return account_player
end

function module.get_client(player)
    if not player then
        error("Invalid player")
    end

    for _, client in pairs(container.clients_all.get()) do
        if not client.player then
            logger.log("Player information lost. Client: " .. json.tostring(client), "E")
            goto continue
        end
        if client.player.username == player.username then
            return client
        end

        ::continue::
    end
end

function module.get_players()
    return container.player_online.get()
end

function module.get_player(account)
    return container.player_online.get(account.username)
end

function module.get_chunk(pos)
    return world.get_chunk_data(pos.x, pos.z)
end

function module.place_block(block_state, pid)
    if type(block_state.id)[1] == 's' then
        block_state.id = block.index(block_state.id)
    end

    block.place(block_state.x, block_state.y, block_state.z, block_state.id, block_state.states, pid)

    if block_state.rotation then
        block.set_rotation(block_state.x, block_state.y, block_state.z, block_state.rotation)
    end
end

function module.destroy_block(pos, pid)
    block.destruct(pos.x, pos.y, pos.z, pid)
end

function module.set_player_state(account_player, state)
    if state.x and state.y and state.z then
        player.set_pos(account_player.pid, state.x, state.y, state.z)
    end

    if state.yaw and state.pitch then
        player.set_rot(account_player.pid, state.yaw, state.pitch, 0)
    end

    if state.noclip ~= nil and state.flight ~= nil then
        player.set_noclip(account_player.pid, state.noclip)
        player.set_flight(account_player.pid, state.flight)
    end
end

function module.get_player_state(account_player)
    local x, y, z = player.get_pos(account_player.pid)
    local yaw, pitch = player.get_rot(account_player.pid)
    local noclip = player.is_noclip(account_player.pid)
    local flight = player.is_flight(account_player.pid)

    return {
        x = x,
        y = y,
        z = z,
        yaw = yaw,
        pitch = pitch,
        noclip = noclip,
        flight = flight
    }
end

function module.set_day_time(time)
    if time == "day" then
        time = 0.5
    elseif time == "night" then
        time = 0
    elseif type(time)[1] ~= 'n' and not tonumber(time) then
        return false
    elseif tonumber(time) < 0 then
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

function module.set_inventory(_player, inv)
    inventory.set_inv(player.get_inventory(_player.pid), inv)
end

function module.get_inventory(_player)
    local invid, slot = player.get_inventory(_player.pid)
    return {
        invid = invid,
        slot = slot,
        inventory = inventory.get_inv(invid)
    }
end

function module.set_selected_slot(_player, slot_id)
    player.set_selected_slot(_player.pid, slot_id)
end

function module.by_invid.get(invid)

    for _, player in pairs(module.get_players()) do
        if player.invid == invid then
            return player
        end
    end
end

--Вынужденый ужас
--TODO: В СРОЧНОМ ПОРЯДКЕ ЗАСУНУТЬ ЭТО В БОЛЕЕ ПРАВИЛЬНОЕ МЕСТО
do
    local inventory_funcs = {
        set = inventory.set, set_count = inventory.set_count,
        add = inventory.add, remove = inventory.remove,
        set_data = inventory.set_data, decrement = inventory.decrement,
        use = inventory.use
    }

    for name, func in pairs(inventory_funcs) do
        inventory[name] = function (invid, ...)
            local res = {func(invid, ...)}

            local prefix = parse_path(debug.getinfo(2, "S").source)

            if prefix ~= "server" then
                local player = module.by_invid.get(invid)
                if not player then
                    return unpack(res)
                end

                player.inv_is_changed = true
            end

            return unpack(res)
        end
    end
end

return protect.protect_return(module)