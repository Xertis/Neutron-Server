local events = {}

local ServerEcho = {}

function ServerEcho.put_event(func, ...)
    local exclients = {}
    for i = 1, select('#', ...) do
        exclients[select(i, ...)] = true
    end
    events[#events + 1] = { func = func, exclients = exclients }
end

function ServerEcho.proccess(clients)
    local to_remove = {}
    for i = 1, #events do
        local event = events[i]
        for _, client in ipairs(clients) do
            local socket = client.socket
            if socket and socket:is_alive() and not event.exclients[client] then
                event.func(client)
            end
        end
        to_remove[i] = true
    end

    for i, _ in ipairs(to_remove) do
        events[i] = nil
    end
end

return ServerEcho
