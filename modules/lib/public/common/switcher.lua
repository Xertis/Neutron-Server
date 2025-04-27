local switcher = {}
switcher.__index = switcher

function switcher.new(func)
    local self = setmetatable({}, switcher)

    self.switchs = {}
    self.func = func

    return self
end

function switcher:add_case(val, func)
    self.switchs[val] = {func = func}
end

function switcher:add_middleware(val, middleware)
    if self.switch[val] then
        local middlewares = table.set_default(self.switch[val], "middlewares", {})

        table.insert(middlewares,middleware)
    else
        error("The paсket handler was not found")
    end
end

function switcher:switch(key, ...)
    if self.switchs[key] == nil then
        return self.func(...)
    end

    if self.switchs[key].middlewares then
        local args = table.deep_copy({...})
        for _, middleware in ipairs(self.switchs[key].middlewares) do
            if not middleware(unpack(args)) then
                return
            end
        end
    end

    return self.switchs[key].func(...)
end

return switcher