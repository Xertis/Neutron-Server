local entities_manager = start_require "lib/private/entities/entities_manager"

local module = {}

function module.register(entity_name, config)
    entities_manager.register(entity_name, config)
end

function module.despawn(uid)
    entities_manager.despawn(uid)

    local entity = entities.get(uid)
    if entity then
        entity:despawn()
    else
        error(string.format(
            "The entity with uid: %s does not exist",
            uid
            )
        )
    end
end

return module