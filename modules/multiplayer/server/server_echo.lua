local protect = require "lib/private/protect"

local events = {}

local ServerEcho = {}

function ServerEcho.put_event(func)
    table.insert(events, func)
end

function ServerEcho.proccess(clients)
    for event_index, event in ipairs(events) do
        for _, client in ipairs(clients) do
            local socket = client.network.socket
            if socket and socket:is_alive() then
                event(client)
            end
        end
        table.remove(events, event_index)
    end
end

return protect.protect_return(ServerEcho)