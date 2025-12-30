local sandbox = start_require("server:lib/private/sandbox/sandbox")
local account_manager = start_require("server:lib/private/accounts/account_manager")
local protocol = start_require("server:multiplayer/protocol-kernel/protocol")

local module = {
    players = {},
    world = {},
    blocks = {}
}

function module.players.is_username_available(username, identity)
    return sandbox.is_username_available(username, identity)
end

function module.players.get_client(player)
    return sandbox.get_client(player)
end

function module.players.get_all()
    local players = sandbox.get_players()

    return players
end

function module.players.get_player(account)
    return sandbox.get_player(account)
end

function module.players.sync_states(_player, states)
    local client = account_manager.by_username.get_client(_player.username)

    if states.pos then
        player.set_pos(_player.pid, states.pos.x, states.pos.y, states.pos.z)
    end

    if states.rot then
        player.set_rot(_player.pid, states.rot.x, states.rot.y, states.rot.z)
    end

    if states.cheats then
        player.set_noclip(_player.pid, states.cheats.noclip)
        player.set_flight(_player.pid, states.cheats.flight)
    end

    client:push_packet(protocol.ServerMsg.SynchronizePlayer, {data = states})
end

function module.players.get_in_radius(target_pos, radius)
    target_pos = target_pos or {}

    if not target_pos.x or not radius then
        error("missing position or radius")
    end

    local res = {}
    local x, y, z = target_pos.x, target_pos.y, target_pos.z

    for key, _player in pairs(sandbox.get_players()) do
        local x2, y2, z2 = player.get_pos(_player.pid)

        if math.euclidian3D(x, y, z, x2, y2, z2) <= radius then
            res[key] = _player
        end
    end

    return res
end

function module.players.get_by_pid(pid)
    local pid_type = type(pid)
    if pid_type ~= "number" then
        error("pid (number) expected, got " .. pid_type)
    end

    for _, _player in pairs(sandbox.get_players()) do
        if _player.pid == pid then
            return _player
        end
    end
end

function module.blocks.sync_inventory(pos, client)
    local invid = inventory.get_block(pos.x, pos.y, pos.z)
    local inv = inventory.get_inv(invid)

    client:push_packet(protocol.ServerMsg.BlockInventory, {
        pos = {x = pos.x, y = pos.y, z = pos.z},
        inventory = inv
    })
end

function module.blocks.sync_slot(pos, slot, client)
    client:push_packet(protocol.ServerMsg.BlockInventorySlot, {
        pos = {x = pos.x, y = pos.y, z = pos.z},
        slot_id = slot.slot_id,
        item_id = slot.item_id,
        item_count = slot.item_count
    })
end

return module