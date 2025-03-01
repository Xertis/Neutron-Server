local protect = require "lib/private/protect"

local module = {}
local delayed_responses = {}

function module.push(func, args, time_out)
    table.insert(delayed_responses, {
        responce_func = func,
        args = args,
        time_create = time.uptime(),
        time_out = time_out
    }
)
end

function module.process()
    for i, responce in ipairs(delayed_responses) do
        if time.uptime() - responce.time_create > responce.time_out then
            table.remove(delayed_responses, i)
        else
            local state = responce.responce_func(unpack(responce.args))
            if state then
                table.remove(delayed_responses, i)
            end
        end
    end
end

return protect.protect_return(module)