local protect = require "lib/private/protect"
if protect.protect_require() then return end

local protocol = require "multiplayer/protocol-kernel/protocol"
local server_echo = require "multiplayer/server/server_echo"

local module = {}
local reg_entities = {}
local player_fields = {}
local entities_data = {}

local culling = function (pid, pos, target_pos)
    return vec3.culling(player.get_dir(pid), pos, target_pos, 120)
end

function module.register(entity_name, config, handler)
    if PLAYER_ENTITY_ID == entities.def_name(entity_name) then
        error("You cannot register an entity responsible for a player, to create custom fields use entities.players.add_custom_field")
    end

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

function module.add_field(type, key, field)
    if not table.has({"custom_fields", "models", "textures", "components"}, type) then
        error("Incorrect type for entity field")
    end

    local fields = table.set_default(player_fields, type, {})
    if fields[key] then
        return false
    end

    fields[key] = field

    return true
end

function module.despawn(uid)
    entities_data[uid] = nil

    local buffer = protocol.create_databuffer()
    buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.EntityDespawn, uid))

    server_echo.put_event(
        function (client)
            client:queue_response(buffer.bytes)
        end
    )
end

local function __create_data(entity, is_player)
    local uid = entity:get_uid()
    local str_name = entity:def_name()
    local tsf = entity.transform
    local body = entity.rigidbody
    local rig = entity.skeleton
    local conf = nil
    local data = {}

    if not is_player then
        conf = reg_entities[str_name].config
        data.standart_fields = {
            tsf_rot = tsf:get_rot(),
            tsf_pos = tsf:get_pos(),
            tsf_size = tsf:get_size(),
            body_size = body:get_size(),
        }
    else
        conf = player_fields
    end

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
    for field_name, field in pairs(conf.custom_fields or conf) do
        if (conf == player_fields and field_name ~= "textures" and field_name ~= "models" and field_name ~= "components")
        or (conf ~= player_fields and conf.custom_fields) then
            local val = field.provider(uid, field_name)
            local val_type = type(val)
            if not table.has({"number", "string", "boolean", "table"}, val_type) then
                error("Non-serializable data type got: " .. val_type)
            end
            custom_fields[field_name] = val
        end
    end
    data.custom_fields = custom_fields

    return data
end

local function __get_dirty(entity, data, cur_data, p_pos, e_pos, is_player)
    local dirty = table.deep_copy(cur_data)
    local str_name = entity:def_name()
    local dist = 0

    if not is_player then
        dist = math.euclidian3D(
            e_pos[1], e_pos[2], e_pos[3],
            p_pos[1], p_pos[2], p_pos[3]
        )
    end

    for fields_type, type in pairs(cur_data) do
        for field_name, cur_val in pairs(type) do
            local config = is_player and player_fields[fields_type] or reg_entities[str_name].config[fields_type]
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

local function __send_dirty(entity, uid, id, dirty, client, is_player)

    if table.count_pairs(dirty.standart_fields or {}) == 0 then
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
    if not is_player then
        local data = {uid, id, dirty}
        buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.EntityUpdate, unpack(data)))
    else
        local data = {entity:get_player(), dirty}
        buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.PlayerFieldsUpdate, unpack(data)))
    end

    client:queue_response(buffer.bytes)
end

function module.process(client)
    local c_player = client.player
    local pid = c_player.pid
    local p_pos = {player.get_pos(pid)}

    for _, uid in pairs(entities.get_all_in_radius(p_pos, RENDER_DISTANCE)) do
        local entity = entities.get(uid)

        if not entity then
            goto continue
        end

        local tsf = entity.transform

        local id = entity:def_index()
        local is_player = PLAYER_ENTITY_ID == id

        if is_player then
            local entity_pid = entity:get_player()
            if entity_pid == ROOT_PID then
                goto continue
            end
        end

        local str_name = entity:def_name()
        local _data = reg_entities[str_name] or {}
        if not _data.config and not is_player then
            logger.log("Spawn of an unregistered entity: " .. str_name)
            goto continue
        end

        local cur_data = __create_data(entity, is_player)
        local data = table.set_default(entities_data, uid, {})

        if not data[pid] then
            data[pid] = {}
        end

        local e_pos = tsf:get_pos()
        data = data[pid]

        if not is_player then
            local cul_pos = table.get_default(data, "standart_fields", "tsf_pos") or (is_player and e_pos or tsf:get_pos())
            local last_culling = culling(pid, p_pos, cul_pos)
            local cur_culling = culling(pid, p_pos, e_pos)

            if not (last_culling or cur_culling) then
                goto continue
            end
        end

        local dirty = __get_dirty(entity, data, cur_data, p_pos, e_pos, is_player)
        __update_data(data, dirty, cur_data)
        __send_dirty(entity, uid, id, dirty, client, is_player)

        ::continue::
    end
end

return module