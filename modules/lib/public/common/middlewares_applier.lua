local applier = {}
applier.__index = applier

function applier.new(func)
    local self = setmetatable({}, applier)

    self.func = func
    self.middlewares = {}

    return self
end

function applier:add_middleware(func)
    table.insert(self.middlewares, func)
end

function applier:process(...)
    for _, middleware in ipairs(self.middlewares) do
        local res = middleware(...)
        if not res then
            return
        end
    end

    return self.func(...)
end

return applier