local entities_manager = start_require "lib/private/entities/entities_manager"

logger.log("Patching the in-memory engine before start")

--- Патчим сущностей

local entities_despawn = entities.despawn
entities["despawn"] = function (eid)
    entities_despawn(eid)
    entities_manager.despawn(eid)
end

-- Патчим чтобы работало так, как в доках, а то хуня

-- local player_set_suspended = player.set_suspended
-- local player_is_suspended = player.is_suspended

-- function player.set_suspended(pid, susi)
--     player_set_suspended(pid, not susi)
-- end

-- function player.is_suspended(pid)
--     return not player_is_suspended(pid)
-- end