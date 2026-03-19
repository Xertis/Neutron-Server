local api = {}

local self = Module({
    on_block_update = function() end,
    on_world_open = function() end,
    on_world_save = function() end
})

local headless = self.headless
local single = self.single

function headless.on_block_update(blockid, x, y, z, playerid)
    local data = {
        block = {
            pos = { x = x, y = y, z = z },
            state = block.get_states(x, y, z),
            id = block.get(x, y, z)
        },
        pid = playerid
    }

    local buffer = api.protocol.create_databuffer()
    buffer:put_packet(api.protocol.build_packet("server", api.protocol.ServerMsg.BlockChanged, data))

    api.server_echo.put_event(
        function(client)
            if client.active ~= true then return end
            local client_states = api.sandbox.get_player_state(client.player)

            if math.euclidian2D(
                    client_states.x,
                    client_states.z,
                    x,
                    z
                ) > RENDER_DISTANCE then
                return
            end

            if not client:interceptor_process(api.protocol.ServerMsg.BlockChanged, data) then
                return
            end

            client:queue_response(buffer.bytes)
        end
    )
end

function single.on_world_open()
    require "run/standalone"
end

function on_world_open()
    self:build()
    self.on_world_open()
    api = {
        server_echo = import "lib/flow/server_echo",
        protocol = import "net/protocol/protocol",
        sandbox = import "core/sandbox/methods"
    }
end

function on_world_save()
    self.on_world_save()
end

function on_block_placed(...)
    self.on_block_update(...)
end

function on_block_broken(...)
    self.on_block_update(...)
end

events.on("server:block_interact", function(...)
    self.on_block_update(...)
end)
