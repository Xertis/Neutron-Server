local entities_manager = start_require "lib/private/entities/entities_manager"

local module = {}

function module.register(entity_name, config, handler)
    entities_manager.register(entity_name, config, handler)
end

return module