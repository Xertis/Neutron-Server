local Pipeline = {}
Pipeline.__index = Pipeline

function Pipeline.new()
    local self = setmetatable({}, Pipeline)
    self._middlewares = {}
    self._values = {}
    return self
end

function Pipeline:add_middleware(func)
    if type(func) == "function" then
        table.insert(self._middlewares, func)
    end
end

function Pipeline:process(values)
    table.map(values, function (_, value)
        return {state = 1, val = value}
    end)

    while #values > 0 do
        for i=#values, 1, -1 do
            local item = values[i]

            local res, reload = self._middlewares[item.state](item.val)

            if res ~= nil and not reload then
                item.state = item.state + 1
            elseif res ~= nil then
                item.val = res
            end

            if item.state > #self._middlewares or res == nil then
                table.remove(values, i)
            end
        end
    end
end

return Pipeline