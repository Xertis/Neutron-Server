local api = require "api/api".server
local entities_manager = start_require "lib/private/entities/entities_manager"
local entities_despawn = entities.despawn

logger.log("Patching the in-memory engine before start")

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