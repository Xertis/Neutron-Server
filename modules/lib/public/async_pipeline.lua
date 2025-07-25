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

local function run_client(client, middlewares)
    local ctx = { client = client }
    function ctx.await()
        ctx.awaited = true
        coroutine.yield()
        ctx.awaited = false
    end

    for _, mw in ipairs(middlewares) do
        local status, result = pcall(mw, ctx)

        if not status then
            return "break"
        end
        if result == "break" then
            return "break"
        end
        if ctx.awaited then
            break
        end
    end
    return "done"
end

function Pipeline:process(clients, max_iterations)
    max_iterations = max_iterations or 1024
    local execution_quota = {}
    local active_coroutines = {}

    for _, client in ipairs(clients) do
        client.meta.quota = self.quota_function(client)
        execution_quota[client] = client.meta.quota
        local co = coroutine.create(function()
            return run_client(client, self._middlewares)
        end)
        table.insert(active_coroutines, { co = co, client = client })
    end

    local iterations = 0
    while iterations < max_iterations and #active_coroutines > 0 do
        iterations = iterations + 1

        table.sort(active_coroutines, function(a, b)
            return execution_quota[a.client] > execution_quota[b.client]
        end)

        for i = #active_coroutines, 1, -1 do
            local entry = active_coroutines[i]
            local co, client = entry.co, entry.client

            local success, result = coroutine.resume(co)

            if not success then
                table.remove(active_coroutines, i)
            else
                local status = coroutine.status(co)
                if status == "dead" then
                    if result == "break" then
                        table.remove(active_coroutines, i)
                    else
                        execution_quota[client] = execution_quota[client] - 1
                        if execution_quota[client] <= 0 then
                            table.remove(active_coroutines, i)
                        else
                            local new_co = coroutine.create(function()
                                return run_client(client, self._middlewares)
                            end)
                            entry.co = new_co
                        end
                    end
                end
            end
        end
    end
end

return Pipeline