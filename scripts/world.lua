local function start_require(path)
    if not string.find(path, ':') then
        local prefix, _ = parse_path(debug.getinfo(2).source)
        return start_require(prefix..':'..path)
    end

    local prefix, file = parse_path(path)
    path = prefix..":modules/"..file..".lua"

    if not _G["/$p"] then
        return
    end

    return _G["/$p"][path]
end

local server_echo = start_require("server:multiplayer/server/server_echo")
local protocol = start_require("server:multiplayer/protocol-kernel/protocol")
local sandbox = start_require("server:lib/private/sandbox/sandbox")

local function upd(blockid, x, y, z, playerid)
    playerid = math.max(playerid, 0)

    local data = {
        x,
        y,
        z,
        block.get_states(x, y, z),
        block.get(x, y, z),
        playerid
    }

    local buffer = protocol.create_databuffer()
    buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.BlockChanged, unpack(data)))

    server_echo.put_event(
        function (client)
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

            client.network:send(buffer.bytes)
        end
    )
end

function on_block_placed( ... )
    upd(...)
end

function on_block_broken( ... )
    upd(...)
end

events.on("server:block_interact", function (...)
    upd(...)
end)