local switcher = {}
switcher.__index = switcher

function switcher.new(func)
    local self = setmetatable({}, switcher)

    self.switchs = {}
    self.func = func

    return self
end

function switcher:add_case(val, func)
    self.switchs[val] = func
end

function switcher:switch(key, ...)
    if self.switchs[key] == nil then
        return self.func(...)
    end

    return self.switchs[key](...)
end

return switcher