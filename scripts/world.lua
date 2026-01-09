local function start_require(path)
    if not string.find(path, ':') then
        local prefix, _ = parse_path(debug.getinfo(2).source)
        return start_require(prefix..':'..path)
    end

    local old_path = path
    local prefix, file = parse_path(path)
    path = prefix..":modules/"..file..".lua"

    if not _G["/$p"] then
        return require(old_path)
    end

    return _G["/$p"][path]
end

local server_echo = nil
local protocol = nil
local sandbox = nil

local function upd(blockid, x, y, z, playerid)

    if not server_echo or not protocol or not sandbox then
        return
    end

    playerid = math.max(playerid, 0)

    local data = {
        block = {
            pos = {x = x, y = y, z = z},
            state = block.get_states(x, y, z),
            id = block.get(x, y, z)
        },
        pid = playerid
    }

    local buffer = protocol.create_databuffer()
    buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.BlockChanged, data))

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

            if not client:interceptor_process(protocol.ServerMsg.BlockChanged, data) then
                return
            end

            client:queue_response(buffer.bytes)
        end
    )
end

function on_world_open()
    local init = function ()
        server_echo = start_require("server:multiplayer/server/server_echo")
        protocol = start_require("server:multiplayer/protocol-kernel/protocol")
        sandbox = start_require("server:lib/private/sandbox/sandbox")
    end

    if IS_RUNNING then
        init()
        return
    end

    events.on("server:__initialization_completed", function ()
        init()
    end)
end

function on_world_tick()
    events.emit("server:__world_tick")

    debug.print({
        pos = {player.get_pos(1)},
        flight = player.is_flight(1),
        suspend = player.is_suspended(1)
    })
end

function on_world_save()
    events.emit("server:__world_save")
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