local server_echo = nil
local protocol = nil
local sandbox = nil

local function upd(blockid, x, y, z, playerid)
    playerid = math.max(playerid, 0)

    local data = {
        block = {
            pos = { x = x, y = y, z = z },
            state = block.get_states(x, y, z),
            id = block.get(x, y, z)
        },
        pid = playerid
    }

    local buffer = protocol.create_databuffer()
    buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.BlockChanged, data))

    server_echo.put_event(
        function(client)
            if client.active ~= true then
                return
            end

            local client_states = sandbox.get_player_state(client.player)

            if math.euclidian2D(
                    client_states.x,
                    client_states.z,
                    x,
                    z
                ) > RENDER_DISTANCE then
                return
            end

            if not client:interceptor_process(protocol.ServerMsg.BlockChanged, data) then
                return
            end

            client:queue_response(buffer.bytes)
        end
    )
end

function on_world_open()
    server_echo = import("server:lib/flow/server_echo")
    protocol = import("server:net/protocol/protocol")
    sandbox = import("server:core/sandbox/methods")
end

function on_block_placed(...)
    upd(...)
end

function on_block_broken(...)
    upd(...)
end

events.on("server:block_interact", function(...)
    upd(...)
end)
