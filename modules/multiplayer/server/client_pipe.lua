local Pipeline = require "lib/public/pipeline"
local protocol = require "lib/public/protocol"
local protect = require "lib/private/protect"
local sandbox = require "lib/private/sandbox/sandbox"
local account_manager = require "lib/private/accounts/account_manager"

local ClientPipe = Pipeline.new()

--Отправляем игровое время
ClientPipe:add_middleware(function(client)

    local buffer = protocol.create_databuffer()

    buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.TimeUpdate, world.get_day_time()))
    client.network:send(buffer.bytes)
    return client
end)

--Запрос на логин/регистрацию
ClientPipe:add_middleware(function(client)
    if not CONFIG.server.password_auth then
        return client
    end

    local account = client.account

    if not account.is_logged then
        local account_player = sandbox.get_player(account)
        local state = sandbox.get_player_state(account_player)
        local yaw, pitch = player.get_rot(account_player.pid, true)
        DATA = {state.x, state.y, state.z, yaw, pitch}

        local buffer = protocol.create_databuffer()
        buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.SynchronizePlayerPosition, unpack(DATA)))
        client.network:send(buffer.bytes)
    end

    return client
end)

--Обновляем позицию у других
ClientPipe:add_middleware(function(client)

    for _, player in pairs(sandbox.get_players()) do
        if table.has(RESERVED_USERNAMES, player.username) then
            goto continue
        end

        local state = sandbox.get_player_state(player)

        local buffer = protocol.create_databuffer()
        local DATA = {
            player.pid,
            state.x,
            state.y,
            state.z,
            state.yaw,
            state.pitch
        }

        buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.PlayerMoved, unpack(DATA)))
        client.network:send(buffer.bytes)

        ::continue::
    end

    return client
end)

return protect.protect_return(ClientPipe)