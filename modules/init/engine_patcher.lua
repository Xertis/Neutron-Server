local entities_manager = start_require "lib/private/entities/entities_manager"

logger.log("Patching the in-memory engine before start")

--- Патчим сущностей

local entities_despawn = entities.despawn
entities["despawn"] = function (eid)
    entities_despawn(eid)
    entities_manager.despawn(eid)
end