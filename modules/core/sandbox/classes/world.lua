local metadata = import "lib/data/metadata"
local World = {}
World.__index = World

local world_proxy = metadata.proxy("server", "worlds")

function World.new(name)
    local self = setmetatable({}, World)

    self.active = false
    self.name = name
    self.rules = {}

    return self
end

function World:is_active()
    return self.active
end

function World:abort()
    self.active = false
    self:save()
end

function World:save()
    world_proxy[self.name] = self:to_save()
end

function World:revive()
    if self.active then return true end
    local data = world_proxy[self.name]
    if not data then return false end

    self.active = true
    self:to_load(data)
    return true
end

function World:to_save()
    return {
        name = self.name,
        rules = self.rules
    }
end

function World:to_load(data)
    self.name = data.name
    self.rules = data.rules
end

return World
