local protocol = import "net/protocol/protocol"

local Observer = {}
Observer.__index = Observer

local function get_states(entity, player_pos, prev_state, config)
    local uid = entity:get_uid()
    local tsf = entity.transform
    local body = entity.rigidbody
    local rig = entity.skeleton

    local dist = vec3.distance(tsf:get_pos(), player_pos)

    local current_data = {}

    if config.standard_fields then
        current_data.standard_fields = {
            tsf_rot = tsf:get_rot(),
            tsf_pos = tsf:get_pos(),
            tsf_size = tsf:get_size(),
            body_size = body:get_size(),
            body_material = body:get_material(),
            body_mass = body:get_mass(),
            body_elastic = body:get_elasticity()
        }
    end

    if config.textures then
        current_data.textures = {}
        for key, field in pairs(config.textures) do
            if field.provider then
                current_data.textures[key] = field.provider(uid, key)
            else
                current_data.textures[key] = rig:get_texture(key)
            end
        end
    end

    if config.models then
        current_data.models = {}
        for key, field in pairs(config.models) do
            if field.provider then
                current_data.models[key] = field.provider(uid, key)
            else
                current_data.models[key] = rig:get_model(key)
            end
        end
    end

    if config.matrix then
        current_data.matrix = {}
        for key, field in pairs(config.matrix) do
            if field.provider then
                current_data.matrix[key] = field.provider(uid, key)
            else
                current_data.matrix[key] = rig:get_matrix(key)
            end
        end
    end

    if config.components then
        current_data.components = {}
        for component, val in pairs(config.components) do
            local is_on = val.provider(uid, component)
            if type(is_on) ~= "boolean" then
                error("Incorrect state of the component")
            end
            current_data.components[component] = is_on
        end
    end

    local custom_fields = {}
    if config.custom_fields then
        for field_name, field in pairs(config.custom_fields) do
            local val = field.provider(uid, field_name)
            local val_type = type(val)
            if not table.has({ "number", "string", "boolean", "table", "nil" }, val_type) then
                error("Non-serializable data type got: " .. val_type)
            end
            custom_fields[field_name] = val
        end
    end

    current_data.custom_fields = custom_fields

    local dirty = {}

    for category, fields in pairs(current_data) do
        for field_name, field_value in pairs(fields) do
            if not config[category][field_name] then
                goto continue
            end

            local evaluate_deviation = config[category][field_name].evaluate_deviation
            local maximum_deviation = config[category][field_name].maximum_deviation

            local prev_field_value = (prev_state[category] or {})[field_name]

            local deviation = evaluate_deviation(dist, field_value, prev_field_value)
            if math.abs(deviation) > maximum_deviation then
                local dirty_category = table.set_default(dirty, category, {})
                dirty_category[field_name] = field_value
            end
            ::continue::
        end
    end

    return current_data, dirty
end

local function send_dirty(observer, dirty)
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

    if observer.is_spawned then
        observer.client:push_packet(protocol.ServerMsg.EntityUpdate, { uid = observer.uid, dirty = dirty })
    else
        observer.client:push_packet(protocol.ServerMsg.EntitySpawn,
            { uid = observer.uid, def = observer.id, dirty = dirty, args = observer.args })
    end
end

function Observer.new(client, uid, config)
    local self = setmetatable({}, Observer)

    self.client = client
    self.uid = uid
    self.config = config
    self.sended_state = {}

    self.player = client.player
    self.entity = entities.get(uid)
    self.id = self.entity:def_index()
    self.is_spawned = false

    if config.on_client_spawn then
        self.args = config.on_client_spawn(client.player, uid)
    end

    return self
end

function Observer:despawn()
    local func_despawn = self.config.on_client_despawn
    if func_despawn then func_despawn(self.player, self.uid) end
end

function Observer:process()
    local player_pos = { player.get_pos(self.player.pid) }
    local current_state, dirty = get_states(self.entity, player_pos, self.sended_state, self.config)

    self.sended_state = current_state

    send_dirty(self, dirty)
    if not self.is_spawned then self.is_spawned = true end
end

return Observer
