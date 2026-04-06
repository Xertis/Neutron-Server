local server_echo = import "lib/flow/server_echo"
local protocol = import "net/protocol/protocol"
local sandbox = import "core/sandbox/methods"

local global_block = _G["block"]
PACK_ENV["block"] = {
    set = global_block.set
}
setmetatable(PACK_ENV["block"], {
    __index = function(t, key)
        local val = rawget(t, key)
        if val ~= nil then
            return val
        end
        return global_block[key]
    end
})

local function update(x, y, z, id)
    local data = {
        block = {
            pos = { x = x, y = y, z = z },
            state = block.get_states(x, y, z),
            id = id
        },
        pid = -1
    }

    local buffer = protocol.create_databuffer()
    buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.BlockChanged, data))

    server_echo.put_event(
        function(client)
            if client.active ~= true then return end
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

local set = block.set
function global_block.set(x, y, z, id, states, noupdate)
    set(x, y, z, id, states, noupdate)
    update(x, y, z, id)
end
