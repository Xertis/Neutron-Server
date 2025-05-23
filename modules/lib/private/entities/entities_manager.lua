local protect = require "lib/private/protect"
if protect.protect_require() then return end

local protocol = require "lib/public/protocol"
local server_echo = require "multiplayer/server/server_echo"

local module = {}
local reg_entities = {}
local entities_data = {}

local culling = function (pid, pos, target_pos)
    return vec3.culling(player.get_dir(pid), pos, target_pos, 120)
end

function module.register(entity_name, config, handler)
    reg_entities[entity_name] = {
        config = config,
        spawn_handler = handler
    }
end

function module.get_reg_config(entity_name)
    return reg_entities[entity_name]
end

function module.clear_pid(pid)
    for _, data in pairs(entities_data) do
        if data[pid] then
            data[pid] = nil
        end
    end
end

function module.despawn(uid)
    entities_data[uid] = nil

    local buffer = protocol.create_databuffer()
    buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.EntityDespawn, uid))

    server_echo.put_event(
        function (client)
            client.network:send(buffer.bytes)
        end
    )
end

local function __create_data(entity)
    local uid = entity:get_uid()
    local str_name = entity:def_name()
    local tsf = entity.transform
    local body = entity.rigidbody
    local rig = entity.skeleton

    local conf = reg_entities[str_name].config

    local data = {
        standart_fields = {
            tsf_rot = tsf:get_rot(),
            tsf_pos = tsf:get_pos(),
            tsf_size = tsf:get_size(),
            body_size = body:get_size(),
        },
    }

    if conf.textures then
        data.textures = {}
        for key, _ in pairs(conf.textures) do
            data.textures[key] = rig:get_texture(key)
        end
    end

    if conf.models then
        data.models = {}
        for key, _ in pairs(conf.models) do
            data.models[key] = rig:get_model(key)
        end
    end

    if conf.components then
        data.components = {}
        for component, val in pairs(conf.components) do
            local is_on = val.provider(uid, component)

            if type(is_on) ~= "boolean" then
                error("Incorrect state of the component")
            end

            data.components[component] = is_on
        end
    end

    local custom_fields = {}

    for field_name, field in pairs(conf.custom_fields) do
        custom_fields[field_name] = field.provider(uid, field_name)
    end

    data.custom_fields = custom_fields

    return data
end

local function __get_dirty(entity, data, cur_data, p_pos, e_pos)
    local dirty = table.deep_copy(cur_data)
    local str_name = entity:def_name()
    local dist = math.euclidian3D(
        e_pos[1], e_pos[2], e_pos[3],
        p_pos[1], p_pos[2], p_pos[3]
    )

    for fields_type, type in pairs(cur_data) do

        for field_name, cur_val in pairs(type) do
            local config = reg_entities[str_name].config[fields_type][field_name]

            table.set_default(data, fields_type, {})
            local value = data[fields_type][field_name]
            local max_deviation = config.maximum_deviation
            local eval = config.evaluate_deviation

            local deviation = math.abs(eval(dist, cur_val, value))

            if deviation <= max_deviation then
                dirty[fields_type][field_name] = nil
            end
        end
    end

    return dirty
end

local function __update_data(data, dirty, cur_data)
    for fields_type, type in pairs(dirty) do
        for field_name, _ in pairs(type) do
            data[fields_type][field_name] = cur_data[fields_type][field_name]
        end
    end
end

local function __send_dirty(uid, id, dirty, client)
    local data = {
        uid,
        id,
        dirty
    }

    if table.count_pairs(dirty.standart_fields) == 0 then
        dirty.standart_fields = nil
    end
    if table.count_pairs(dirty.custom_fields or {}) == 0 then
        dirty.custom_fields = nil
    end
    if table.count_pairs(dirty.textures or {}) == 0 then
        dirty.textures = nil
    end
    if table.count_pairs(dirty.components or {}) == 0 then
        dirty.components = nil
    end
    if table.count_pairs(dirty.models or {}) == 0 then
        dirty.models = nil
    end

    if table.count_pairs(dirty) == 0 then
        return
    end

    local buffer = protocol.create_databuffer()
    buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.EntityUpdate, unpack(data)))
    client.network:send(buffer.bytes)
end

function module.process(client)
    local c_player = client.player
    local pid = c_player.pid
    local p_pos = {player.get_pos(pid)}
    local chunk_distance = CONFIG.server.chunks_loading_distance

    local render_distance = (chunk_distance + 5) * 16

    for _, uid in pairs(entities.get_all_in_radius(p_pos, render_distance)) do
        local entity = entities.get(uid)
        local tsf = entity.transform

        local id = entity:def_index()
        local str_id = entity:def_name()

        if not reg_entities[str_id] then
            goto continue
        end

        local cur_data = __create_data(entity)
        local data = table.set_default(entities_data, uid, {})

        if not data[pid] then
            data[pid] = {}
        end

        local e_pos = tsf:get_pos()
        data = data[pid]

        local cul_pos = table.get_default(data, "standart_fields", "tsf_pos") or tsf:get_pos()
        local last_culling = culling(pid, p_pos, cul_pos)
        local cur_culling = culling(pid, p_pos, e_pos)

        if not (last_culling or cur_culling) then
            goto continue
        end

        local dirty = __get_dirty(entity, data, cur_data, p_pos, e_pos)
        __update_data(data, dirty, cur_data)
        __send_dirty(uid, id, dirty, client)

        ::continue::
    end
end

return module