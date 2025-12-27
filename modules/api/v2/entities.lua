local entities_manager = start_require "lib/private/entities/entities_manager"

local HUGE = math.huge

local module = {
    players = {},
    eval = {},
    types = {
        Custom = "custom_fields",
        Standart = "standart_fields",
        Models = "models",
        Textures = "textures",
        Components = "components"
    }
}

function module.register(entity_name, config, handler)
    entities_manager.register(entity_name, config, handler)
end

function module.players.add_field(type, key, config)
    entities_manager.add_field(type, key, config)
end

function module.eval.NotEquals(dist, cur_val, client_val)
    return cur_val ~= client_val and HUGE or 0
end

function module.eval.Always()
    return HUGE
end

function module.eval.Never()
    return 0
end

return module