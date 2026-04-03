local container = import "core/container"
local Player = import "core/sandbox/classes/player"
local metadata = import "lib/data/metadata"
local self = Module({
    by_identity = {},
    by_username = {},
    by_invid = {}
})

local shared = self.shared
local headless = self.headless
local single = self.single

function headless.create_player(account_player)
    local pid = player.create(account_player.username, table.count_pairs(metadata.players.get_all()) + 1)
    logger.log(string.format('Player [#%s] has been created with pid: %s', logger.shorted(account_player.identity), pid))
    account_player.pid = pid

    time.post_runnable(function()
        account_player.entity_id = player.get_entity(pid)
    end)

    local y = 0
    local block_id = block.get(0, y, 0)
    while block_id ~= 0 and block_id ~= -1 do
        y = y + 1
        block_id = block.get(0, y, 0)
    end

    player.set_pos(account_player.pid, 0, y + 1, 0)
    player.set_spawnpoint(account_player.pid, 0, y + 1, 0)
    account_player.world = CONFIG.game.main_world
    account_player.active = true

    local invid, _ = player.get_inventory(account_player.pid)
    account_player.invid = invid
end

function single.create_player(account_player)
    local pid = ROOT_PID

    logger.log(string.format('Player [#%s] has been created with pid: %s', logger.shorted(account_player.identity), pid))
    account_player.pid = pid
    account_player.entity_id = player.get_entity(account_player.pid)

    local y = 0
    local block_id = block.get(0, y, 0)
    while block_id ~= 0 and block_id ~= -1 do
        y = y + 1
        block_id = block.get(0, y, 0)
    end

    player.set_pos(account_player.pid, 0, y + 1, 0)
    player.set_spawnpoint(account_player.pid, 0, y + 1, 0)
    account_player.world = CONFIG.game.main_world
    account_player.active = true

    local invid, _ = player.get_inventory(account_player.pid)
    account_player.invid = invid
end

function shared.join_player(username, account)
    local identity = account.identity
    if table.has(table.freeze_unpack(RESERVED_USERNAMES), username:lower()) then
        logger.log(string.format('The username "%s" is reserved for the system and cannot be used by a client.', username))
        return
    end

    local account_player = container.player_online.get(identity) or Player.new(username, identity)

    local status = account_player:revive()

    if status == CODES.players.ReviveSuccess or status == CODES.players.WithoutChanges then
        if username ~= account_player.username then
            if not self.is_username_available(account_player.username, identity) then
                logger.log(
                    string.format(
                        'The username "%s" is already taken by another user and is not available for [#%s]',
                        username,
                        logger.shorted(identity)
                    ),
                    'E'
                )

                return
            end

            player.set_name(account_player.pid, username)
            logger.log(string.format('The username of player "%s" [#%s] has been changed to "%s"',
                account_player.username, logger.shorted(identity), username))
            account_player.username = username
        end
    elseif status == CODES.players.DataLoss then
        if not self.is_username_available(account_player.username, identity) then
            logger.log(
                string.format(
                    'The username "%s" is already taken by another user and is not available for [#%s]',
                    username,
                    logger.shorted(identity)
                ),
                'E'
            )

            return
        end

        self.create_player(account_player)
    end

    if account_player:is_active() then
        container.player_online.put(identity, account_player)
    end

    logger.log(string.format('Player "%s" [#%s] joined.', account_player.username, logger.shorted(identity)))
    account_player:save()

    local is_suspended = player.is_suspended(account_player.pid)
    logger.log(string.format('Suspend state of player "%s" is %s', account_player.username, tostring(is_suspended)))
    if is_suspended then
        player.set_suspended(account_player.pid, false)
        logger.log(string.format('Suspend state of player "%s" changed to false', account_player.username))
    end

    time.post_runnable(function()
        account_player.entity_id = player.get_entity(account_player.pid)
    end)

    return account_player
end

function shared.leave_player(account_player)
    account_player:abort()

    logger.log(string.format('Player "%s" [#%s] left.', account_player.username, logger.shorted(account_player.identity)))

    container.player_online.put(account_player.identity, nil)

    player.set_suspended(account_player.pid, true)
    logger.log(string.format('Suspend state of player "%s" is true', account_player.username))

    return account_player
end

function shared.get_client(player)
    if not player then
        error("Invalid player")
    end

    for _, client in pairs(container.clients_all.get()) do
        if not client.player then
            logger.log("Player information lost. Client: " .. json.tostring(client), "E")
            goto continue
        end
        if client.player.identity == player.identity then
            return client
        end

        ::continue::
    end
end

function shared.is_username_available(username, identity)
    local metadata_players = metadata.players.get_all()
    local online_players = container.player_online.get()

    for _, player in pairs(metadata_players) do
        if player.username == username and player.identity ~= identity then
            return false
        end
    end

    for _, player in pairs(online_players) do
        if player.username == username and player.identity ~= identity then
            return false
        end
    end

    return true
end

function shared.get_players(key_is_name)
    local players = container.player_online.get()

    if not key_is_name then
        return players
    end

    local changed = {}
    for _, player in pairs(players) do
        changed[player.username] = player
    end

    return changed
end

function shared.get_player(account)
    return container.player_online.get(account.identity)
end

function shared.by_identity.get_player(identity)
    return container.player_online.get(identity)
end

function shared.get_chunk(pos)
    return world.get_chunk_data(pos.x, pos.z)
end

function shared.place_block(block_state, pid)
    if type(block_state.id)[1] == 's' then
        block_state.id = block.index(block_state.id)
    end

    block.place(block_state.x, block_state.y, block_state.z, block_state.id, block_state.states, pid)

    if block_state.rotation then
        block.set_rotation(block_state.x, block_state.y, block_state.z, block_state.rotation)
    end
end

function shared.destroy_block(pos, pid)
    block.destruct(pos.x, pos.y, pos.z, pid)
end

function shared.set_player_state(account_player, state)
    local pid = account_player.pid

    if state.x and state.y and state.z then
        player.set_pos(pid, state.x, state.y, state.z)
    end

    if state.x_rot and state.y_rot and state.z_rot then
        player.set_rot(pid, state.x_rot, state.y_rot, state.z_rot)
    end

    if state.noclip ~= nil and state.flight ~= nil then
        player.set_noclip(pid, state.noclip)
        player.set_flight(pid, state.flight)
    end

    if state.infinite_items then
        player.set_infinite_items(pid, state.infinite_items)
    end

    if state.instant_destruction then
        player.set_instant_destruction(pid, state.instant_destruction)
    end

    if state.interaction_distance then
        player.set_interaction_distance(pid, state.interaction_distance)
    end
end

function shared.get_player_state(account_player)
    local x, y, z = player.get_pos(account_player.pid)
    local x_rot, y_rot, z_rot = player.get_rot(account_player.pid)
    local noclip = player.is_noclip(account_player.pid)
    local flight = player.is_flight(account_player.pid)
    local infinite_items = player.is_infinite_items(account_player.pid)
    local instant_destruction = player.is_instant_destruction(account_player.pid)
    local interaction_distance = player.get_interaction_distance(account_player.pid)

    return {
        x = x,
        y = y,
        z = z,
        x_rot = x_rot,
        y_rot = y_rot,
        z_rot = z_rot,
        noclip = noclip,
        flight = flight,
        infinite_items = infinite_items,
        instant_destruction = instant_destruction,
        interaction_distance = interaction_distance
    }
end

function shared.set_day_time(time)
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

function shared.by_identity.is_online(identity)
    if container.player_online.get(identity) then
        return true
    end

    return false
end

function shared.by_username.is_online(username)
    return self.by_username.get(username) ~= nil
end

function shared.by_username.get(username)
    for _, player in pairs(self.get_players()) do
        if player.username == username then
            return player
        end
    end
end

function shared.set_inventory(_player, inv)
    inventory.set_inv(player.get_inventory(_player.pid), inv)
end

function shared.get_inventory(_player)
    local invid, slot = player.get_inventory(_player.pid)
    return {
        invid = invid,
        slot = slot,
        inventory = inventory.get_inv(invid)
    }
end

function shared.set_selected_slot(_player, slot_id)
    player.set_selected_slot(_player.pid, slot_id)
end

function shared.by_invid.get(invid)
    for _, player in pairs(self.get_players()) do
        if player.invid == invid then
            return player
        end
    end
end

return self:build()
