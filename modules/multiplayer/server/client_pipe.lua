local Pipeline = require "lib/public/pipeline"
local protocol = require "lib/public/protocol"
local protect = require "lib/private/protect"
local sandbox = require "lib/private/sandbox/sandbox"
local entities_manager = require "lib/private/entities/entities_manager"
local weather_manager = require "lib/private/weather/weather_manager"
local particles_manager = require "lib/private/particles/particles_manager"
local matches = require "multiplayer/server/server_matches"

local ClientPipe = Pipeline.new()

--Отправляем игровое время
ClientPipe:add_middleware(function(client)

    local buffer = protocol.create_databuffer()
    local time = time.day_time_to_uint16(world.get_day_time())

    buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.TimeUpdate, time))
    client.network:send(buffer.bytes)
    return client
end)

--Чекаем пинг
ClientPipe:add_middleware(function(client)
    local cur_time = time.uptime()

    if cur_time - client.ping.last_upd < 5 then
        return client
    end

    local buffer = protocol.create_databuffer()

    buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.KeepAlive, math.random(0, 200)))
    client.network:send(buffer.bytes)
    client.ping.last_upd = cur_time
    return client
end)

--Чекаем чанки
ClientPipe:add_middleware(function(client)
    if not client.account.is_logged then
        return client
    elseif not client.meta.chunks_queue then
        return client
    end

    matches.client_online_handler:switch(protocol.ClientMsg.RequestChunks, client.meta.chunks_queue, client)
    client.meta.chunks_queue = nil

    return client
end)

--Обновляем инвентарь
ClientPipe:add_middleware(function (client)
    local player = client.player

    if not player.inv_is_changed then
        return client
    end

    player.inv_is_changed = false

    local data = sandbox.get_inventory(player)
    local inv, slot = data.inventory, data.slot

    local buffer = protocol.create_databuffer()
    buffer = protocol.create_databuffer()
    buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.PlayerInventory, inv))
    client.network:send(buffer.bytes)

    buffer = protocol.create_databuffer()
    buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.PlayerHandSlot, slot))
    client.network:send(buffer.bytes)

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
        DATA = {state.x, state.y, state.z, state.yaw, state.pitch, state.noclip, state.flight}

        local buffer = protocol.create_databuffer()
        buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.SynchronizePlayerPosition, unpack(DATA)))
        client.network:send(buffer.bytes)
    end

    return client
end)

--Обновляем мобов
ClientPipe:add_middleware(function(client)
    if not client.account.is_logged then
        return client
    end

    entities_manager.process(client)

    return client
end)

--Обновляем погоду
ClientPipe:add_middleware(function(client)
    if not client.account.is_logged then
        return client
    end

    local cplayer = client.player
    local cur_weather = table.set_default(cplayer.temp, "current-weather", {})
    local pos = {player.get_pos(cplayer.pid)}

    local weather = weather_manager.get_by_pos(pos[1], pos[3])
    local DATA = nil

    if not weather then
        if cur_weather == nil then
            return client
        end

        DATA = {{}, 1, "clear"}
        cur_weather = nil
    end

    if weather then
        if table.deep_equals(cur_weather or {}, weather.weather) then
            return client
        end

        local packet_time = weather.time_transition
        if weather.time_start + weather.time_transition < time.uptime() then
            packet_time = 1
        end

        DATA = {
            weather.weather,
            packet_time,
            weather.name
        }

        cur_weather = weather.weather
    end

    local buffer = protocol.create_databuffer()
    buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.WeatherChanged, unpack(DATA)))
    client.network:send(buffer.bytes)
    return client
end)

-- Обновляем партиклы
ClientPipe:add_middleware(function(client)
    if not client.account.is_logged then
        return client
    end

    local cplayer = client.player
    local pos = {player.get_pos(cplayer.pid)}

    local cur_particles = table.set_default(cplayer.temp, "current-particles", {})
    local particles = particles_manager.get_in_radius(pos[1], pos[3], RENDER_DISTANCE)
    local particles_with_pid = {}
    local dirty_particles = {}
    local changed_origin_particles = {}

    local function compare_origins(origin1, origin2)
        if type(origin1) == "table" and type(origin2) == "table" then
            return table.equals(origin1, origin2)
        end
        return origin1 == origin2
    end

    for _, particle in ipairs(particles) do
        local pid = particle.pid
        local current_particle = nil
        for _, cp in ipairs(cur_particles) do
            if cp.pid == pid then
                current_particle = cp
                break
            end
        end

        if not current_particle then
            particles_with_pid[pid] = particle
            table.insert(cur_particles, {pid = pid, origin = particle.origin})
            table.insert(dirty_particles, pid)
        elseif not compare_origins(current_particle.origin, particle.origin) then
            particles_with_pid[pid] = particle
            current_particle.origin = particle.origin
            table.insert(changed_origin_particles, pid)
        end
    end

    local to_stop = {}
    for _, cp in ipairs(cur_particles) do
        local found = false
        for _, particle in ipairs(particles) do
            if particle.pid == cp.pid then
                found = true
                break
            end
        end
        if not found then
            table.insert(to_stop, cp.pid)
        end
    end

    for _, pid in ipairs(to_stop) do
        for i, cp in ipairs(cur_particles) do
            if cp.pid == pid then
                table.remove(cur_particles, i)
                break
            end
        end
        local buffer = protocol.create_databuffer()
        buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.ParticleStop, pid))
        client.network:send(buffer.bytes)
    end

    for _, pid in ipairs(dirty_particles) do
        local particle = particles_with_pid[pid]
        local buffer = protocol.create_databuffer()
        buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.ParticleEmit, particle))
        client.network:send(buffer.bytes)
    end

    for _, pid in ipairs(changed_origin_particles) do
        local particle = particles_with_pid[pid]
        local buffer = protocol.create_databuffer()
        buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.ParticleOrigin, particle))
        client.network:send(buffer.bytes)
    end

    return client
end)

--Обновляем позицию у других
ClientPipe:add_middleware(function(client)

    local client_states = sandbox.get_player_state(client.player)

    for _, player in pairs(sandbox.get_players()) do
        if table.has(RESERVED_USERNAMES, player.username) then
            goto continue
        end

        local state = sandbox.get_player_state(player)

        if math.euclidian2D(
            client_states.x,
            client_states.z,
            state.x,
            state.z
        ) > (CONFIG.server.chunks_loading_distance+5) * 16 then
            return client
        end

        local buffer = protocol.create_databuffer()
        local DATA = {
            player.pid,
            state.x,
            state.y,
            state.z,
            state.yaw,
            state.pitch,
            state.noclip,
            state.flight
        }

        buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.PlayerMoved, unpack(DATA)))
        client.network:send(buffer.bytes)

        ::continue::
    end

    return client
end)

return protect.protect_return(ClientPipe)