local Pipeline = {}
Pipeline.__index = Pipeline

function Pipeline.new()
    local self = setmetatable({}, Pipeline)
    self._middlewares = {}
    self.quota_function = function() return 1 end
    return self
end

function Pipeline:add_middleware(func)
    table.insert(self._middlewares, func)
end

function Pipeline:set_quota_function(func)
    self.quota_function = func
end

function Pipeline:process(clients, max_iterations)
    max_iterations = max_iterations or 1024
    local active_clients = {}
    local execution_quota = {}

    for _, client in ipairs(clients) do
        client.meta.quota = self.quota_function(client)
        table.insert(active_clients, client)
        execution_quota[client] = client.meta.quota
    end

    for _ = 1, max_iterations do
        if #active_clients == 0 then break end

        table.sort(active_clients, function(a, b)
            return execution_quota[a] > execution_quota[b]
        end)

        for i = #active_clients, 1, -1 do
            local client = active_clients[i]

            local ctx = { client = client, awaited = false }
            function ctx.await()
                ctx.awaited = true
            end

            for _, middleware in ipairs(self._middlewares) do
                local status, result = pcall(middleware, ctx)

                if not status or result == "break" then
                    table.remove(active_clients, i)
                    break
                end

                if ctx.awaited then
                    break
                end
            end

            if not ctx.awaited then
                execution_quota[client] = execution_quota[client] - 1
            end

            if execution_quota[client] <= 0 then
                table.remove(active_clients, i)
            end
        end
    end
end


return Pipeline