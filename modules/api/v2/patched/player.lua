local server_echo = import "server:lib/flow/server_echo"
local protocol = import "server:net/protocol/protocol"
local sandbox = import "server:api/v2/sandbox"

local global_player = _G["player"]

PACK_ENV["player"] = table.deep_copy(global_player)

local function get_client_by_pid(pid)
    local player_obj = sandbox.players.get_by_pid(pid)

    if not player_obj then return end
    return sandbox.players.get_client(player_obj)
end

function global_player.set_name(pid, name)
    local player_obj = sandbox.players.get_by_pid(pid)
    local identity = player_obj.identity

    if not sandbox.players.is_username_available(name, identity) then
        logger.log(
            string.format('The username "%s" is already taken by another user and is not available for [#%s]', name,
                logger.shorted(identity)),
            'E'
        )

        return
    end

    player.set_name(pid, name)
    player_obj.username = name
end

function global_player.set_pos(pid, x, y, z)
    player.set_pos(pid, x, y, z)

    local client = get_client_by_pid(pid)
    if not client then return end

    client:push_packet(protocol.ServerMsg.SynchronizePlayer, {
        data = {
            pos = { x = x, y = y, z = z }
        }
    })
end

function global_player.set_rot(pid, x, y, z)
    player.set_rot(pid, x, y, z)

    local client = get_client_by_pid(pid)
    if not client then return end

    client:push_packet(protocol.ServerMsg.SynchronizePlayer, {
        data = {
            rot = { x = x, y = y, z = z }
        }
    })
end

function global_player.set_infinite_items(pid, val)
    player.set_infinite_items(pid, val)

    local client = get_client_by_pid(pid)
    if not client then return end

    client:push_packet(protocol.ServerMsg.SynchronizePlayer, {
        data = {
            infinite_items = val
        }
    })
end

function global_player.set_instant_destruction(pid, val)
    player.set_instant_destruction(pid, val)

    local client = get_client_by_pid(pid)
    if not client then return end

    client:push_packet(protocol.ServerMsg.SynchronizePlayer, {
        data = {
            instant_destruction = val
        }
    })
end

function global_player.set_interaction_distance(pid, val)
    player.set_interaction_distance(pid, val)

    local client = get_client_by_pid(pid)
    if not client then return end

    client:push_packet(protocol.ServerMsg.SynchronizePlayer, {
        data = {
            interaction_distance = val
        }
    })
end
