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

function Pipeline:add_value(value)
    table.insert(self._values, value)
end

function Pipeline:process(values)
    self._values = #self._values > 0 and self._values or values
    local results = {}

    for _, middleware in ipairs(self._middlewares) do
        for i, value in ipairs(self._values) do
            if results[i] == nil then
                results[i] = value
            end
            if results[i] ~= nil then
                results[i] = middleware(results[i])
            end
        end
    end

    return results
end

return Pipeline