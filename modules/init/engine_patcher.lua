local api = require "api/api".server
local entities_manager = start_require "lib/private/entities/entities_manager"
local entities_despawn = entities.despawn

entities["despawn"] = function (eid)
    entities_despawn(eid)
    entities_manager.despawn(eid)
end