local protect = require "lib/private/protect"

local events = {}

local ServerEcho = {}

function ServerEcho.put_event(func, ...)
    local exclients = {}
    for i = 1, select('#', ...) do
        exclients[select(i, ...)] = true
    end
    table.insert(events, {func = func, exclients = exclients})
end

function ServerEcho.proccess(clients)
    local to_remove = {}
    for i = 1, #events do
        local event = events[i]
        for _, client in ipairs(clients) do
            local socket = client.network.socket
            if socket and socket:is_alive() and not event.exclients[client] then
                event.func(client)
            end
        end
        to_remove[i] = true
    end

    for i, _ in pairs(to_remove) do
        table.remove(events, i)
    end
end

return protect.protect_return(ServerEcho)