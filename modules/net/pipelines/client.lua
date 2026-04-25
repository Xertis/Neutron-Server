local Pipeline = import "lib/flow/pipeline"
local protocol = import "net/protocol/protocol"
local sandbox = import "core/sandbox/methods"
local inventories_manager = import "core/sandbox/managers/inventories"
local matches = import "net/handlers/main"

local entities_manager = import "core/sandbox/managers/entities"
local weather_manager = import "core/sandbox/managers/weather"
local particles_manager = import "core/sandbox/managers/particles"
local audio_manager = import "core/sandbox/managers/audio"
local text3d_manager = import "core/sandbox/managers/text3d"
local wraps_manager = import "core/sandbox/managers/blockwraps"

local ClientPipe = Pipeline.new()

--Отправляем игровое время
ClientPipe:add_middleware(function(client)
    client:push_packet(protocol.ServerMsg.TimeUpdate, { game_time = world.get_day_time() })
    return client
end)

--Чекаем пинг
ClientPipe:add_middleware(function(client)
    local cur_time = time.uptime()

    if client.ping.waiting or cur_time - client.ping.last_upd < 5 then
        return client
    end

    client:push_packet(protocol.ServerMsg.KeepAlive, { challenge = math.random(0, 255) })
    client.ping.last_upd = cur_time
    client.ping.waiting = true
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
ClientPipe:add_middleware(function(client)
    local player = client.player

    local inventories_for_sync = { player }
    local inventories_close = false

    for id, action_type in pairs(player.pending_inventories) do
        if action_type then
            inventories_for_sync[#inventories_for_sync + 1] = id
        else
            inventories_close = true
        end
    end

    if not inventories_close then
        inventories_manager.sync(unpack(inventories_for_sync))
    else
        inventories_manager.close_inventory(player)
    end

    player.pending_inventories = {}

    return client
end)

--Запрос на логин/регистрацию
ClientPipe:add_middleware(function(client)
    local account = client.account

    if not account.is_logged then
        local account_player = sandbox.get_player(account)
        local state = sandbox.get_player_state(account_player)
        local data = {
            pos = { x = state.x, y = state.y, z = state.z },
            rot = { x = state.x_rot, y = state.y_rot, z = state.z_rot },
            cheats = { noclip = state.noclip, flight = state.flight }
        }

        client:push_packet(protocol.ServerMsg.SynchronizePlayer, { data = data })
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
    local cur_weather = table.set_default(cplayer.temp, "current-weather", nil)
    local pos = { player.get_pos(cplayer.pid) }

    local weather = weather_manager.get_by_pos(pos[1], pos[3])
    local data = nil
    local should_update = false

    if not weather then
        if cur_weather == nil then
            return client
        end

        data = { weather = {}, time = 1, name = "clear" }
        should_update = true
    else
        if not table.deep_equals(cur_weather or {}, weather.weather) then
            local packet_time = weather.time_transition
            if weather.time_start + weather.time_transition < time.uptime() then
                packet_time = 1
            end

            data = {
                weather = weather.weather,
                time = packet_time,
                name = weather.name
            }
            should_update = true
        end
    end

    if should_update then
        cplayer.temp["current-weather"] = weather and weather.weather or nil
        client:push_packet(protocol.ServerMsg.WeatherChanged, data)
    end

    return client
end)

-- Обновляем партиклы
ClientPipe:add_middleware(function(client)
    if not client.account.is_logged then
        return client
    end

    local cplayer = client.player

    local cur_particles = table.set_default(cplayer.temp, "current-particles", {})
    local particles = particles_manager.get_in_radius(cplayer)
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
            table.insert(cur_particles, { pid = pid, origin = particle.origin })
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
        client:push_packet(protocol.ServerMsg.ParticleStop, { pid = pid })
    end

    for _, pid in ipairs(dirty_particles) do
        local particle = particles_with_pid[pid]
        client:push_packet(protocol.ServerMsg.ParticleEmit, { particle = particle })
    end

    for _, pid in ipairs(changed_origin_particles) do
        local particle = particles_with_pid[pid]
        client:push_packet(protocol.ServerMsg.ParticleOrigin, { pid = particle.pid, origin = particle.origin })
    end

    return client
end)

--Обновляем аудио
ClientPipe:add_middleware(function(client)
    if not client.account.is_logged then
        return client
    end

    local cplayer = client.player

    local client_speakers = table.set_default(cplayer.temp, "current-speakers", {})
    local speakers = audio_manager.get_in_radius(cplayer)

    local stopped_speakers = {}
    local spawned_speakers = {}
    local changed_speakers = {}

    local server_speakers_ids = {}
    for _, speaker in ipairs(speakers) do
        server_speakers_ids[speaker.id] = true
    end

    for id, client_speaker in pairs(client_speakers) do
        if not server_speakers_ids[id] then
            table.insert(stopped_speakers, { id = id })
            client_speakers[id] = nil
        end
    end

    for _, server_speaker in ipairs(speakers) do
        local client_speaker = client_speakers[server_speaker.id]

        if not client_speaker then
            client_speakers[server_speaker.id] = table.copy(server_speaker)
            table.insert(spawned_speakers, server_speaker)
        elseif not table.deep_equals(server_speaker, client_speaker) then
            client_speakers[server_speaker.id] = table.copy(server_speaker)
            table.insert(changed_speakers, server_speaker)
        end
    end

    for _, stopped in ipairs(stopped_speakers) do
        client:push_packet(protocol.ServerMsg.AudioStop, { id = stopped.id })
    end

    for _, spawned in ipairs(spawned_speakers) do
        client:push_packet(protocol.ServerMsg.AudioEmit, { audio = spawned })
    end

    for _, changed in ipairs(changed_speakers) do
        client:push_packet(protocol.ServerMsg.AudioState, { state = changed })
    end

    return client
end)

-- Обновляем тексты
ClientPipe:add_middleware(function(client)
    if not client.account.is_logged then
        return client
    end

    local cplayer         = client.player
    local client_text3ds  = table.set_default(cplayer.temp, "current-text3ds", {})
    local text3ds         = text3d_manager.get_in_radius(cplayer)

    local stopped_text3ds = {}
    local spawned_text3ds = {}
    local changed_state   = {}
    local changed_pos     = {}
    local changed_entity  = {}
    local changed_axis    = {}

    local server_ids      = {}
    for _, t in ipairs(text3ds) do
        server_ids[t.id] = true
    end

    for id in pairs(client_text3ds) do
        if not server_ids[id] then
            table.insert(stopped_text3ds, id)
            client_text3ds[id] = nil
        end
    end

    for _, srv in ipairs(text3ds) do
        local cli = client_text3ds[srv.id]

        if not cli then
            client_text3ds[srv.id] = table.copy(srv)
            table.insert(spawned_text3ds, srv)
        elseif not table.deep_equals(srv, cli) then
            client_text3ds[srv.id] = table.copy(srv)

            local pos_changed      = not table.deep_equals(srv.position, cli.position)
            local entity_changed   = srv.entity ~= cli.entity
            local axisX_changed    = not table.deep_equals(srv.axisX, cli.axisX)
            local axisY_changed    = not table.deep_equals(srv.axisY, cli.axisY)

            local function core_changed(a, b)
                return a.text ~= b.text
                    or not table.deep_equals(a.preset, b.preset)
                    or not table.deep_equals(a.extension, b.extension)
            end

            if core_changed(srv, cli) then
                local diff = table.conj(srv, cli)
                diff.id = srv.id
                diff.axisX, diff.axisY = nil, nil
                diff.position, diff.entity = nil, nil
                table.insert(changed_state, diff)
            end

            if pos_changed then
                table.insert(changed_pos, { id = srv.id, pos = srv.position })
            end

            if entity_changed then
                table.insert(changed_entity, { id = srv.id, uid = srv.entity })
            end

            if axisX_changed then
                table.insert(changed_axis, { id = srv.id, axis = srv.axisX or { 1, 0, 0 }, is_x = true })
            end

            if axisY_changed then
                table.insert(changed_axis, { id = srv.id, axis = srv.axisY or { 0, 1, 0 }, is_x = false })
            end
        end
    end

    -- Отправка пакетов
    for _, id in ipairs(stopped_text3ds) do
        client:push_packet(protocol.ServerMsg.Text3DHide, { id })
    end

    for _, spawned in ipairs(spawned_text3ds) do
        client:push_packet(protocol.ServerMsg.Text3DShow, { spawned })
    end

    for _, state in ipairs(changed_state) do
        client:push_packet(protocol.ServerMsg.Text3DState, { state })
    end

    for _, p in ipairs(changed_pos) do
        client:push_packet(protocol.ServerMsg.Text3DPos, { p.id, p.pos })
    end

    for _, e in ipairs(changed_entity) do
        client:push_packet(protocol.ServerMsg.Text3DEntity, { e.id, e.uid })
    end

    for _, ax in ipairs(changed_axis) do
        client:push_packet(protocol.ServerMsg.Text3DAxis, {
            id = ax.id, axis = ax.axis, is_x = ax.is_x
        })
    end

    return client
end)

--Обновляем обёртки у других
ClientPipe:add_middleware(function(client)
    if not client.account.is_logged then
        return client
    end

    local cplayer = client.player

    local client_wraps = table.set_default(cplayer.temp, "current-wraps", {})
    local wraps = wraps_manager.get_in_radius(cplayer)

    local to_show = {}
    local to_hide = {}
    local to_change_pos = {}
    local to_change_texture = {}
    local to_change_faces = {}
    local to_change_tints = {}

    for id, client_wrap in pairs(client_wraps) do
        local found = false
        for _, wrap in ipairs(wraps) do
            if wrap.id == id then
                found = true
                break
            end
        end

        if not found then
            table.insert(to_hide, client_wrap)
            client_wraps[id] = nil
        end
    end

    for _, wrap in ipairs(wraps) do
        local client_wrap = client_wraps[wrap.id]

        if not client_wrap then
            local wrap_copy = table.deep_copy(wrap)
            client_wraps[wrap.id] = wrap_copy
            table.insert(to_show, wrap_copy)
        else
            if not table.deep_equals(wrap.pos, client_wrap.pos) then
                client_wrap.pos = table.deep_copy(wrap.pos)
                table.insert(to_change_pos, {
                    id = wrap.id,
                    pos = client_wrap.pos
                })
            end

            if not table.deep_equals(wrap.faces or {}, client_wrap.faces or {}) then
                client_wrap.faces = table.deep_copy(wrap.faces)
                table.insert(to_change_faces, {
                    id = wrap.id,
                    faces = client_wrap.faces
                })
            end

            if not table.deep_equals(wrap.tints or {}, client_wrap.tints or {}) then
                client_wrap.tints = table.deep_copy(wrap.tints)
                table.insert(to_change_tints, {
                    id = wrap.id,
                    faces = client_wrap.tints
                })
            end

            if wrap.texture ~= client_wrap.texture then
                client_wrap.texture = wrap.texture
                table.insert(to_change_texture, {
                    id = wrap.id,
                    texture = client_wrap.texture
                })
            end
        end
    end

    for _, wrap in ipairs(to_show) do
        local wrap_pos = wrap.pos
        client:push_packet(protocol.ServerMsg.WrapShow, {
            id = wrap.id,
            pos = {
                x = wrap_pos[1],
                y = wrap_pos[2],
                z = wrap_pos[3]
            },
            texture = wrap.texture,
            emission = wrap.emission
        })

        if wrap.faces then
            client:push_packet(protocol.ServerMsg.WrapSetFaces, {
                id = wrap.id,
                faces = wrap.faces
            })
        end

        if wrap.tints then
            client:push_packet(protocol.ServerMsg.WrapSetTints, {
                id = wrap.id,
                faces = wrap.tints
            })
        end
    end

    for _, wrap in ipairs(to_hide) do
        client:push_packet(protocol.ServerMsg.WrapHide, { wrap.id })
    end

    for _, wrap in ipairs(to_change_pos) do
        local wrap_pos = wrap.pos
        client:push_packet(protocol.ServerMsg.WrapSetPos, {
            id = wrap.id,
            pos = {
                x = wrap_pos[1],
                y = wrap_pos[2],
                z = wrap_pos[3]
            }
        })
    end

    for _, wrap in ipairs(to_change_texture) do
        client:push_packet(protocol.ServerMsg.WrapSetTexture, { id = wrap.id, texture = wrap.texture })
    end

    for _, wrap in ipairs(to_change_faces) do
        client:push_packet(protocol.ServerMsg.WrapSetFaces, {
            id = wrap.id,
            faces = wrap.faces
        })
    end

    for _, wrap in ipairs(to_change_tints) do
        client:push_packet(protocol.ServerMsg.WrapSetTints, {
            id = wrap.id,
            faces = wrap.tints
        })
    end

    return client
end)

-- Спи
-- --Обновляем позицию у других
-- ClientPipe:add_middleware(function(client)
--     local function approx_equals(a, b, eps)
--         eps = eps or 0.001
--         for k, v in pairs(a) do
--             if math.abs(v - (b[k] or 0)) >= eps then
--                 return false
--             end
--         end
--         return true
--     end

--     local client_states = sandbox.get_player_state(client.player)
--     local prev_states = table.set_default(client.player.temp, "player-prev-states", {})
--     local lib_player = player
--     for _, player in pairs(sandbox.get_players()) do
--         if table.has(RESERVED_USERNAMES, player.username) or player.username == client.player.username then
--             goto continue
--         end
--         local state = sandbox.get_player_state(player)
--         if math.euclidian2D(client_states.x, client_states.z, state.x, state.z) > VIEW_DISTANCE then
--             goto continue
--         end
--         local prev_state                  = prev_states[player.pid] or {}
--         local changed_data                = { pid = player.pid, data = {} }

--         local current_pos                 = { x = state.x, y = state.y, z = state.z }
--         local current_rot                 = { x = state.x_rot, y = state.y_rot, z = state.z_rot }
--         local current_cheats              = { noclip = state.noclip, flight = state.flight }
--         local current_invid, current_slot = lib_player.get_inventory(player.pid)
--         local current_hand_item           = inventory.get(current_invid, current_slot)

--         if not prev_state.pos or not approx_equals(prev_state.pos, current_pos) then
--             changed_data.data.pos = current_pos
--         end
--         if not prev_state.rot or not approx_equals(prev_state.rot, current_rot) then
--             changed_data.data.rot = current_rot
--         end

--         if not prev_state.cheats or not table.deep_equals(prev_state.cheats, current_cheats) then
--             changed_data.data.cheats =
--                 current_cheats
--         end
--         if not prev_state.hand_item or prev_state.hand_item ~= current_hand_item then
--             changed_data.data.hand_item =
--                 current_hand_item
--         end

--         prev_states[player.pid] = table.deep_copy({
--             pos       = current_pos,
--             rot       = current_rot,
--             cheats    = current_cheats,
--             hand_item = current_hand_item,
--         })

--         if changed_data.data.pos or changed_data.data.rot or changed_data.data.cheats or changed_data.data.hand_item then
--             client:push_packet(protocol.ServerMsg.PlayerMoved, { pid = changed_data.pid, data = changed_data.data })
--         end

--         ::continue::
--     end
--     return client
-- end)

return ClientPipe
