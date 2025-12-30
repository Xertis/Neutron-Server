local server_echo = start_require "server:multiplayer/server/server_echo"
local protocol = start_require "server:multiplayer/protocol-kernel/protocol"
local sandbox = require "server:api/v2/sandbox"

local global_player = _G["player"]

PACK_ENV["player"] = table.deep_copy(global_player)

function global_player.set_name(pid, name)

    local player_obj = sandbox.players.get_by_pid(pid)
    local identity = player_obj.identity

    if not sandbox.players.is_username_available(name, identity) then
        logger.log(
            string.format('The username "%s" is already taken by another user and is not available for [#%s]', name, logger.shorted(identity)),
            'E'
        )

        return
    end

    player.set_name(pid, name)

    player_obj.username = name

    local data = {pid = pid, username = name}
    local buffer = protocol.create_databuffer()
    buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.PlayerUsername, data))

    server_echo.put_event(
        function (client)
            if not client.active then return end

            if client:interceptor_process(protocol.ServerMsg.PlayerUsername, data) then
                client:queue_response(buffer.bytes)
            end
        end
    )
end

function global_player.set_pos(pid, x, y, z)
    player.set_pos(pid, x, y, z)

    local player_obj = sandbox.players.get_by_pid(pid)
    local client = sandbox.players.get_client(player_obj)

    client:push_packet(protocol.ServerMsg.SynchronizePlayer, {data = {
        pos = {x = x, y = y, z = z}
    }})
end

function global_player.set_rot(pid, x, y, z)
    player.set_rot(pid, x, y, z)

    local player_obj = sandbox.players.get_by_pid(pid)
    local client = sandbox.players.get_client(player_obj)

    client:push_packet(protocol.ServerMsg.SynchronizePlayer, {data = {
        rot = {x = x, y = y, z = z}
    }})
end