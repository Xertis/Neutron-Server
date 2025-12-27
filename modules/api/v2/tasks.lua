local List = require "lib/public/common/list"

local module = {}
local tasks = List.new()

function module.add_task(func)
    List.pushleft(tasks, func)
end

events.on("server:client_pipe_start", function ()
    while not List.is_empty(tasks) do
        local func = List.popright(tasks)
        func()
    end
end)

return module