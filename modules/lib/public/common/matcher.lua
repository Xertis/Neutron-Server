local matcher = {}
matcher.__index = matcher

function matcher.new(func)
    local self = setmetatable({}, matcher)

    self.matchers = {}
    self.values = {}
    self.default_data = {}
    self.func = func
    self.pos = 0

    return self
end

function matcher:add_match(func)
    table.insert(self.matchers, func)
end

function matcher:set_default_data(data)
    self.default_data = data
end

function matcher:match(val)
    if self.matchers[self.pos+1](val) == true then
        self.pos = self.pos + 1
        table.insert(self.values, val)
    else
        self.values = {}
    end

    if self.pos >= #self.matchers then
        local res = self.func(self.values)
        self.values = {}
        self.pos = 0

        return res
    end
end

return matcher