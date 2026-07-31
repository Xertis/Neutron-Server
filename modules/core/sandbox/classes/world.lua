local metadata = import "lib/data/metadata"
local World = {}
World.__index = World

local world_proxy = metadata.proxy("server", "worlds")

function World.new(name)
    local self = world_proxy[name]

    if not self then
        self = {
            active = false,
            name = name,
            rules = {}
        }
        world_proxy[name] = self
    end

    self.active = true

    return setmetatable(self, World)
end

function World:is_active()
    return self.active
end

function World:abort()
    self.active = false
end

return World
