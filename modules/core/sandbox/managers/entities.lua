local protocol = import "net/protocol/protocol"
local server_echo = import "lib/flow/server_echo"

local module = {}
local reg_entities = {}
local entities_data = {}
local notificated_entities = {}

local culling = function(pid, target_pos, target_size)
    local fov = 150
    local dir = player.get_dir(pid)
    local pos = { player.get_pos(pid) }
    local half_size = {
        target_size[1] / 2,
        target_size[2],
        target_size[3] / 2
    }
    local vertices = {
        { target_pos[1] - half_size[1], target_pos[2] + half_size[2], target_pos[3] - half_size[3] },
        { target_pos[1] + half_size[1], target_pos[2] + half_size[2], target_pos[3] - half_size[3] },
        { target_pos[1] + half_size[1], target_pos[2] + half_size[2], target_pos[3] + half_size[3] },
        { target_pos[1] - half_size[1], target_pos[2] + half_size[2], target_pos[3] + half_size[3] },

        { target_pos[1] - half_size[1], target_pos[2],                target_pos[3] - half_size[3] },
        { target_pos[1] + half_size[1], target_pos[2],                target_pos[3] - half_size[3] },
        { target_pos[1] + half_size[1], target_pos[2],                target_pos[3] + half_size[3] },
        { target_pos[1] - half_size[1], target_pos[2],                target_pos[3] + half_size[3] }
    }

    for _, vertex in ipairs(vertices) do
        if vec3.culling(dir, pos, vertex, fov) then
            return true
        end
    end

    return vec3.culling(dir, pos, target_pos, fov)
end

function module.register(entity_name, config, handler)
    if config.models then
        local new_models = {}
        for index, value in pairs(config.models) do
            new_models[tonumber(index)] = value
            logger.log("Entity model indexes must be number", "W")
        end
        config.models = new_models
    end

    reg_entities[entity_name] = {
        config = config,
        spawn_handler = handler
    }
    logger.log(string.format('The entity "%s" is registered.', entity_name))
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

function module.clear_entity_for_pid(pid, uid)
    if entities_data[uid] then
        entities_data[uid][pid] = nil
    end
end

function module.despawn(uid)
    entities_data[uid] = nil

    local buffer = protocol.create_databuffer()
    buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.EntityDespawn, { uid }))

    server_echo.put_event(
        function(client)
            client:queue_response(buffer.bytes)
        end
    )
end

local function __create_data(entity)
    local uid = entity:get_uid()
    local str_name = entity:def_name()
    local tsf = entity.transform
    local body = entity.rigidbody
    local rig = entity.skeleton
    local conf = nil
    local data = {}

    conf = reg_entities[str_name].config
    data.standard_fields = {
        tsf_rot = tsf:get_rot(),
        tsf_pos = tsf:get_pos(),
        tsf_size = tsf:get_size(),
        body_size = body:get_size(),
        body_material = body:get_material(),
        body_mass = body:get_mass(),
        body_elastic = body:get_elasticity()
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

    if conf.matrix then
        data.matrix = {}
        for key, _ in pairs(conf.matrix) do
            data.matrix[key] = rig:get_matrix(key)
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
    for field_name, field in pairs(conf.custom_fields or conf) do
        if conf.custom_fields then
            local val = field.provider(uid, field_name)
            local val_type = type(val)
            if not table.has({ "number", "string", "boolean", "table" }, val_type) then
                error("Non-serializable data type got: " .. val_type)
            end
            custom_fields[field_name] = val
        end
    end
    data.custom_fields = custom_fields

    return data
end

local function __get_dirty(entity, data, cur_data, p_pos, e_pos)
    local dirty = table.deep_copy(cur_data)
    local str_name = entity:def_name()
    local dist = 0

    dist = math.euclidian3D(
        e_pos[1], e_pos[2], e_pos[3],
        p_pos[1], p_pos[2], p_pos[3]
    )

    for fields_type, type in pairs(cur_data) do
        for field_name, cur_val in pairs(type) do
            local config = reg_entities[str_name].config[fields_type]
            if config and config[field_name] then
                table.set_default(data, fields_type, {})
                local value = data[fields_type][field_name]
                local max_deviation = config[field_name].maximum_deviation
                local eval = config[field_name].evaluate_deviation
                local deviation = math.abs(eval(dist, cur_val, value))
                if deviation <= max_deviation then
                    dirty[fields_type][field_name] = nil
                end
            else
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

local function __send_dirty(entity, uid, id, dirty, client)
    if table.count_pairs(dirty.standard_fields or {}) == 0 then
        dirty.standard_fields = nil
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
    if table.count_pairs(dirty.matrix or {}) == 0 then
        dirty.matrix = nil
    end

    if table.count_pairs(dirty) == 0 then
        return
    end

    local buffer = protocol.create_databuffer()

    local data = { uid = uid, def = id, dirty = dirty }
    buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.EntityUpdate, data))

    client:queue_response(buffer.bytes)
end

function module.process(client)
    local c_player = client.player
    local pid = c_player.pid
    local p_pos = { player.get_pos(pid) }

    for _, uid in pairs(entities.get_all_in_radius(p_pos, RENDER_DISTANCE)) do
        local entity = entities.get(uid)

        if not entity then
            goto continue
        end

        local tsf = entity.transform
        local body = entity.rigidbody

        local id = entity:def_index()

        if PLAYER_ENTITY_ID == id then
            local entity_pid = entity:get_player()
            if entity_pid == ROOT_PID or entity_pid == pid or player.is_suspended(entity_pid) then
                goto continue
            end
        end

        local str_name = entity:def_name()
        local _data = reg_entities[str_name] or {}
        if not _data.config then
            if not table.has(notificated_entities, str_name) then
                logger.log("Spawn of an unregistered entity: " .. str_name)
                table.insert(notificated_entities, str_name)
            end
            goto continue
        end

        local cur_data = __create_data(entity)
        local data = table.set_default(entities_data, uid, {})

        if not data[pid] then
            data[pid] = {}
        end

        local e_pos = tsf:get_pos()
        local e_size = body:get_size()
        data = data[pid]

        local cul_pos = table.get_default(data, "standard_fields", "tsf_pos") or tsf:get_pos()
        local last_culling = culling(pid, cul_pos, e_size)
        local cur_culling = culling(pid, e_pos, e_size)

        if not (last_culling or cur_culling) then
            goto continue
        end

        local dirty = __get_dirty(entity, data, cur_data, p_pos, e_pos)
        __update_data(data, dirty, cur_data)
        __send_dirty(entity, uid, id, dirty, client)

        ::continue::
    end
end

return module
