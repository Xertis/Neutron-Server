local Pipeline = {}
Pipeline.__index = Pipeline

local in_range = function (val, min, max)
    return val > max and min or val < min and max or val
end

function Pipeline.new()
    local self = setmetatable({}, Pipeline)
    self._middlewares = {}
    self._size = 0
    return self
end

function Pipeline:set_quota_limit(limit)
    self._limit = limit
end

function Pipeline:add_middleware(func)
    assert(type(func) == "function", "Middleware must be a function")
    table.insert(self._middlewares, func)
    self._size = self._size + 1
end

function Pipeline:run(client)
    local size = self._size
    for ware_index=1, size do
        local middleware = self._middlewares[ware_index]
        local result = middleware(client)

        if result == nil or ware_index == size then
            return
        end

        coroutine.yield()
    end
end

function Pipeline:process(process_clients)
    local clients = table.copy(process_clients)
    local size = #clients
    local client_index = size+1

    while size > 0 do
        client_index = in_range(client_index-1, 1, size)
        local client = clients[client_index]

        local client_co = client.meta.pipe_co

        if not client_co then
            client_co = coroutine.create(function ()
                while true do
                    client.meta.pipe_finish = false
                    self:run(client)
                    client.meta.pipe_finish = true
                    coroutine.yield()
                end
            end)
            client.meta.pipe_co = client_co
        end

        coroutine.resume(client_co)
        local status = client.meta.pipe_finish
        if status then
            client.meta.pipe_co = nil
            table.remove(clients, client_index)
            size = size - 1
        end
    end
end

return Pipeline