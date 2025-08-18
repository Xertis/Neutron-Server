local protect = require "lib/private/protect"

local module = {}
local delayed_responses = {}

function module.push(func, args, time_out, step)
    table.insert(delayed_responses, {
        responce_func = func,
        args = args,
        time_create = time.uptime(),
        time_out = time_out,
        step = step or 0
    }
)
end

function module.process()
    for i=#delayed_responses, 1, -1 do
        local responce = delayed_responses[i]
        local cur_time = time.uptime()
        if cur_time - responce.time_create > responce.time_out then
            table.insert(responce.args, true)
            responce.responce_func(unpack(responce.args))
            table.remove(delayed_responses, i)
        elseif (responce.step > 0 and (cur_time - responce.time_create) % responce.step < 0.01) or responce.step == 0 then
            local state = responce.responce_func(unpack(responce.args))
            if state then
                table.remove(delayed_responses, i)
            end
        end
    end
end

return protect.protect_return(module)