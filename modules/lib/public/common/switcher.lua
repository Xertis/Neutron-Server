local switcher = {}
switcher.__index = switcher

function switcher.new(func)
    local self = setmetatable({}, switcher)

    self.switchs = {}
    self.func = func
    self.middleware = nil

    return self
end

function switcher:add_case(val, func)
    self.switchs[val] = {func = func}
end

function switcher:add_middleware(val, middleware)
    self.middleware = middleware
end

function switcher:add_generic_middleware(middleware)
    table.insert(self.generic_middlewares, middleware)
end

function switcher:switch(key, ...)
    if not self.middleware(...) then
        return
    end

    if self.switchs[key] == nil then
        return self.func(...)
    end

    return self.switchs[key].func(...)
end

return switcher