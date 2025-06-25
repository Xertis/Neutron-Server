local api = require "api/api".server
local entities_manager = start_require "lib/private/entities/entities_manager"

logger.log("Patching the in-memory engine before start")

--- Патчим сущностей

local entities_despawn = entities.despawn
entities["despawn"] = function (eid)
    entities_despawn(eid)
    entities_manager.despawn(eid)
end

--- Патчим корутины

local __vc_resume_coroutine_default = __vc_resume_coroutine
local __vc_coroutines = nil

for i = 1, math.huge do
    local name, value = debug.getupvalue(__vc_resume_coroutine_default, i)
    if not name then break end

    if name == "__vc_coroutines" then
        __vc_coroutines = value
        break
    end
end

if __vc_coroutines ~= nil then
    __vc_resume_coroutine = function(id)
        local co = __vc_coroutines[id]
        if not co then return false end

        local success, err = pcall(coroutine.resume, co)
        if not success then
            debug.error(err)
            logger.log("Engine coroutine error: " .. tostring(err), 'P')
        end

        return coroutine.status(co) ~= "dead"
    end
end

-- Патчим чтобы работало так, как в доках, а то хуня

local player_set_suspended = player.set_suspended
local player_is_suspended = player.is_suspended

function player.set_suspended(pid, susi)
    player_set_suspended(not susi)
end

function player.is_suspended(pid)
    return not player_is_suspended(pid)
end