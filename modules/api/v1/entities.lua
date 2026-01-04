local entities_v2 = require "api/v2/entities"

local module = table.deep_copy(entities_v2)

function module.register(entity_name, config, handler)
    config.standard_fields = config.standart_fields
    config.standart_fields = nil

    entities_v2.register(entity_name, config, handler)
end

return module