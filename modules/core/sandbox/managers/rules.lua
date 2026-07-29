local rules = {}

local Rule = {}
Rule.__index = Rule

local reserved_names = {}

function Rule.new(name, default, level)
    if reserved_names[name] then
        error(string.format("A rule named '%s' already exists", name))
    end

    local self = setmetatable({}, Rule)

    self.name = name
    self.default = default
    self.level = level

    self.next_listener_id = 0
    self.listeners = {}

    reserved_names[name] = true

    return self
end

function Rule:listen(listener)
    local id = tohex(self.next_listener_id)
    self.listeners[id] = listener
    self.next_listener_id = self.next_listener_id + 1
    return id
end

function Rule:unlisten(id)
    self.listeners[id] = nil
end

function Rule:process(obj, value)
    for _, listener in pairs(self.listeners) do
        listener(obj, value)
    end
end

function rules.define(name, properties)
    local rule = Rule.new(name, properties.default, properties.level)
    return rule
end

return rules
