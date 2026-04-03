local entities_manager = import "core/sandbox/managers/entities"

local HUGE = math.huge

local module = {
    players = {},
    eval = {},
    types = {
        Custom = "custom_fields",
        Standard = "standard_fields",
        Models = "models",
        Matrix = "matrix",
        Textures = "textures",
        Components = "components"
    }
}

function module.register(entity_name, config, handler)
    entities_manager.register(entity_name, config, handler)
end

function module.eval.NotEquals(dist, cur_val, client_val)
    if type(cur_val) == "table" then
        return not table.deep_equals(cur_val, client_val) and HUGE or 0
    end
    return cur_val ~= client_val and HUGE or 0
end

function module.eval.VectorNotEquals(dist, cur_val, client_val)
    client_val = client_val or {}
    for i, v in ipairs(cur_val) do
        if math.abs(v - (client_val[i] or 0)) > 0.001 then
            return HUGE
        end
    end
    return 0
end

function module.eval.Always()
    return HUGE
end

function module.eval.Never()
    return 0
end

return module
