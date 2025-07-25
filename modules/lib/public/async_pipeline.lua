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
    local heap = {}

    local function heap_insert(entry)
        table.insert(heap, entry)
        local idx = #heap
        while idx > 1 do
            local parent = math.floor(idx / 2)
            if execution_quota[heap[parent].client] >= execution_quota[heap[idx].client] then
                break
            end
            heap[parent], heap[idx] = heap[idx], heap[parent]
            idx = parent
        end
    end

    local function heap_extract_max()
        if #heap == 0 then return nil end
        local max = heap[1]
        heap[1] = heap[#heap]
        heap[#heap] = nil

        local size = #heap
        local idx = 1
        while true do
            local left = 2 * idx
            local right = left + 1
            local largest = idx

            if left <= size and execution_quota[heap[left].client] > execution_quota[heap[largest].client] then
                largest = left
            end
            if right <= size and execution_quota[heap[right].client] > execution_quota[heap[largest].client] then
                largest = right
            end
            if largest == idx then break end

            heap[idx], heap[largest] = heap[largest], heap[idx]
            idx = largest
        end
        return max
    end

    for i = 1, #clients do
        local client = clients[i]
        client.meta = client.meta or {}
        client.meta.quota = self.quota_function(client)
        execution_quota[client] = client.meta.quota

        if not client.meta.pipe_co then
            client.meta.pipe_co = coroutine.create(function()
                return run_client(client, self._middlewares)
            end)
        end

        heap_insert({
            pipe_co = client.meta.pipe_co,
            client = client
        })
    end

    local iterations = 0
    while iterations < max_iterations and #heap > 0 do
        iterations = iterations + 1

        local entry = heap_extract_max()
        local co, client = entry.pipe_co, entry.client
        local success, result = coroutine.resume(co)

        if not success then
            client.meta.pipe_co = nil
        else
            local status = coroutine.status(co)
            if status == "dead" then
                execution_quota[client] = execution_quota[client] - 1
                client.meta.quota = execution_quota[client]

                if result == "break" then
                    client.meta.pipe_co = nil
                elseif execution_quota[client] > 0 then
                    client.meta.pipe_co = coroutine.create(function()
                        return run_client(client, self._middlewares)
                    end)
                    heap_insert({
                        pipe_co = client.meta.pipe_co,
                        client = client
                    })
                else
                    client.meta.pipe_co = nil
                end
            else
                heap_insert(entry)
            end
        end
    end
end

return Pipeline