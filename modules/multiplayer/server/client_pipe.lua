local Pipeline = require "lib/public/pipeline"
local protocol = require "multiplayer/protocol-kernel/protocol"
local protect = require "lib/private/protect"
local sandbox = require "lib/private/sandbox/sandbox"
local matches = require "multiplayer/server/server_matches"

local entities_manager = require "lib/private/entities/entities_manager"
local weather_manager = require "lib/private/gfx/weather_manager"
local particles_manager = require "lib/private/gfx/particles_manager"
local audio_manager = require "lib/private/gfx/audio_manager"
local text3d_manager = require "lib/private/gfx/text3d_manager"
local wraps_manager = require "lib/private/gfx/blockwraps_manager"

local ClientPipe = Pipeline.new()

--Отправляем игровое время
ClientPipe:add_middleware(function(client)
    local time = time.day_time_to_uint16(world.get_day_time())

    client:push_packet(protocol.ServerMsg.TimeUpdate, {game_time = time})
    return client
end)

--Чекаем пинг
ClientPipe:add_middleware(function(client)
    local cur_time = time.uptime()

    if client.ping.waiting or cur_time - client.ping.last_upd < 5 then
        return client
    end

    client:push_packet(protocol.ServerMsg.KeepAlive, {challenge = math.random(0, 255)})
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
ClientPipe:add_middleware(function (client)
    local player = client.player

    if not player.inv_is_changed then
        return client
    end

    player.inv_is_changed = false

    local data = sandbox.get_inventory(player)
    local inv, slot = data.inventory, data.slot

    client:push_packet(protocol.ServerMsg.PlayerInventory, {inventory = inv})
    client:push_packet(protocol.ServerMsg.PlayerHandSlot, {slot = slot})
end)

--Запрос на логин/регистрацию
ClientPipe:add_middleware(function(client)
    local account = client.account

    if not account.is_logged then
        local account_player = sandbox.get_player(account)
        local state = sandbox.get_player_state(account_player)
        local data = {
            pos = {x = state.x, y = state.y, z = state.z},
            rot = {x = state.x_rot, y = state.y_rot, z = state.z_rot},
            cheats = {noclip = state.noclip, flight = state.flight}
        }

        client:push_packet(protocol.ServerMsg.SynchronizePlayer, {data = data})
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
    local pos = {player.get_pos(cplayer.pid)}

    local weather = weather_manager.get_by_pos(pos[1], pos[3])
    local data = nil
    local should_update = false

    if not weather then
        if cur_weather == nil then
            return client
        end

        data = {weather = {}, time = 1, name = "clear"}
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
        client:push_packet(protocol.ServerMsg.ParticleStop, {pid = pid})
    end

    for _, pid in ipairs(dirty_particles) do
        local particle = particles_with_pid[pid]
        client:push_packet(protocol.ServerMsg.ParticleEmit, {particle = particle})
    end

    for _, pid in ipairs(changed_origin_particles) do
        local particle = particles_with_pid[pid]
        client:push_packet(protocol.ServerMsg.ParticleOrigin, {origin = particle})
    end

    return client
end)

--Обновляем аудио
ClientPipe:add_middleware(function(client)
    if not client.account.is_logged then
        return client
    end

    local cplayer = client.player
    local pos = {player.get_pos(cplayer.pid)}

    local client_speakers = table.set_default(cplayer.temp, "current-speakers", {})
    local speakers = audio_manager.get_in_radius(pos[1], pos[2], pos[3], RENDER_DISTANCE)

    local stopped_speakers = {}
    local spawned_speakers = {}
    local changed_speakers = {}

    local server_speakers_ids = {}
    for _, speaker in ipairs(speakers) do
        server_speakers_ids[speaker.id] = true
    end

    for id, client_speaker in pairs(client_speakers) do
        if not server_speakers_ids[id] then
            table.insert(stopped_speakers, {id = id})
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
        client:push_packet(protocol.ServerMsg.AudioStop, {id = stopped.id})
    end

    for _, spawned in ipairs(spawned_speakers) do
        client:push_packet(protocol.ServerMsg.AudioEmit, {audio = spawned})
    end

    for _, changed in ipairs(changed_speakers) do
        client:push_packet(protocol.ServerMsg.AudioState, {state = changed})
    end

    return client
end)

-- Обновляем тексты
ClientPipe:add_middleware(function(client)
    if not client.account.is_logged then
        return client
    end

    local cplayer = client.player
    local pos = {player.get_pos(cplayer.pid)}

    local client_text3ds = table.set_default(cplayer.temp, "current-text3ds", {})
    local text3ds = text3d_manager.get_in_radius(pos[1], pos[3], RENDER_DISTANCE)

    local stopped_text3ds = {}
    local spawned_text3ds = {}
    local changed_text3ds = {}
    local changed_axis = {}

    local server_text3ds_ids = {}
    for _, text3d in ipairs(text3ds) do
        server_text3ds_ids[text3d.id] = true
    end

    for id, client_text3d in pairs(client_text3ds) do
        if not server_text3ds_ids[id] then
            table.insert(stopped_text3ds, {id = id})
            client_text3ds[id] = nil
        end
    end

    for _, server_text3d in ipairs(text3ds) do
        local client_text3d = client_text3ds[server_text3d.id]

        if not client_text3d then
            client_text3ds[server_text3d.id] = table.copy(server_text3d)
            table.insert(spawned_text3ds, server_text3d)
        elseif not table.deep_equals(server_text3d, client_text3d) then
            local temp1 = table.copy(server_text3d)
            local temp2 = table.copy(client_text3d)

            temp1.axisX, temp1.axisY = nil, nil
            temp2.axisX, temp2.axisY = nil, nil
            if not table.deep_equals(temp1, temp2) then
                client_text3ds[server_text3d.id] = table.copy(server_text3d)
                local text = table.conj(server_text3d, client_text3d)
                text.id = server_text3d.id
                table.insert(changed_text3ds, text)
            else
                client_text3ds[server_text3d.id] = table.copy(server_text3d)
                if not table.deep_equals(server_text3d.axisX, client_text3d.axisX) then
                    table.insert(changed_axis, {text = server_text3d, is_x = true})
                end

                if not table.deep_equals(server_text3d.axisY, client_text3d.axisY) then
                    table.insert(changed_axis, {text = server_text3d, is_x = false})
                end
            end
        end
    end

    for _, stopped in ipairs(stopped_text3ds) do
        client:push_packet(protocol.ServerMsg.Text3DHide, {stopped.id})
    end

    for _, spawned in ipairs(spawned_text3ds) do
        client:push_packet(protocol.ServerMsg.Text3DShow, {spawned})
    end

    for _, changed in ipairs(changed_text3ds) do
        client:push_packet(protocol.ServerMsg.Text3DState, {changed})
    end

    for _, changed in ipairs(changed_axis) do
        local axis = nil
        if changed.is_x then
            axis = changed.text.axisX
        else
            axis = changed.text.axisY
        end

        client:push_packet(protocol.ServerMsg.Text3DAxis, {
                id = changed.text.id, axis = axis, is_x = changed.is_x
            }
        )
    end

    return client
end)

--Обновляем обёртки у других
ClientPipe:add_middleware(function(client)
    if not client.account.is_logged then
        return client
    end

    local cplayer = client.player
    local pos = {player.get_pos(cplayer.pid)}

    local client_wraps = table.set_default(cplayer.temp, "current-wraps", {})
    local wraps = wraps_manager.get_in_radius(pos[1], pos[3], RENDER_DISTANCE)

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
        client:push_packet(protocol.ServerMsg.WrapHide, {wrap.id})
    end

    for _, wrap in ipairs(to_change_pos) do
        local wrap_pos = wrap.pos
        client:push_packet(protocol.ServerMsg.WrapSetPos, {id = wrap.id, pos = {
            x = wrap_pos[1],
            y = wrap_pos[2],
            z = wrap_pos[3]
        }})
    end

    for _, wrap in ipairs(to_change_texture) do
        client:push_packet(protocol.ServerMsg.WrapSetTexture, {id = wrap.id, texture = wrap.texture})
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

--Обновляем позицию у других
ClientPipe:add_middleware(function(client)
    local client_states = sandbox.get_player_state(client.player)
    local prev_states = table.set_default(client.player.temp, "player-prev-states", {})
    local lib_player = player
    for _, player in pairs(sandbox.get_players()) do
        if table.has(RESERVED_USERNAMES, player.username) or player.username == client.player.username then
            goto continue
        end

        local state = sandbox.get_player_state(player)

        if math.euclidian2D(
            client_states.x,
            client_states.z,
            state.x,
            state.z
        ) > RENDER_DISTANCE then
            goto continue
        end

        local prev_state = prev_states[player.pid] or {}

        local changed_data = {
            pid = player.pid,
            data = {}
        }

        local current_pos = {x = state.x, y = state.y, z = state.z}

        changed_data.data.compressed = false

        if not prev_state.pos or not table.deep_equals(prev_state.pos, current_pos) then
            changed_data.data.pos = current_pos
        end

        local current_rot = {x = state.x_rot, y = state.y_rot, z = state.z_rot}
        if not prev_state.rot or not table.deep_equals(prev_state.rot, current_rot) then
            changed_data.data.rot = current_rot
        end

        local current_cheats = {noclip = state.noclip, flight = state.flight}
        if not prev_state.cheats or not table.deep_equals(prev_state.cheats, current_cheats) then
            changed_data.data.cheats = current_cheats
        end

        local current_invid, current_slot = lib_player.get_inventory(player.pid)
        local current_hand_item = inventory.get(current_invid, current_slot)
        if not prev_state.hand_item or prev_state.hand_item ~= current_hand_item then
            changed_data.data.hand_item = current_hand_item
        end

        --debug.print(changed_data)

        if changed_data.data.pos or changed_data.data.rot or changed_data.data.cheats or changed_data.data.hand_item then

            client:push_packet(protocol.ServerMsg.PlayerMoved, {pid = changed_data.pid, data = changed_data.data})

            prev_states[player.pid] = table.deep_copy({
                pos = current_pos or prev_state.pos,
                rot = current_rot or prev_state.rot,
                cheats = current_cheats or prev_state.cheats,
                hand_item = current_hand_item or prev_state.hand_item
            })
        end

        ::continue::
    end

    return client
end)

return protect.protect_return(ClientPipe)