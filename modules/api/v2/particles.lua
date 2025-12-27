local particles_manager = start_require("server:lib/private/gfx/particles_manager")
local module = {}

local function stop(id)
    particles_manager.stop(id)
end

local Particles = {}
Particles.__index = Particles

function Particles.new(id)
    local self = setmetatable({}, Particles)

    self.id = id

    return self
end

function Particles:stop()
    if self.id then
        stop(self.id)
        self.id = nil
    end
end

function Particles:is_alive()
    if not self.id then return false end
    return module.get(self.id) and true or false
end

function Particles:get_origin()
    if not self.id then return end

    local particle = module.get(self.id)
    if not particle then return end
    return particle.origin
end

function Particles:get_pos()
    if not self.id then return end
    return particles_manager.get_pos(self.id)
end

function Particles:set_origin(origin)
    if not self.id then return end

    local particle = module.get(self.id)
    particle.origin = origin
end

----------------------------------------

function module.get(id)
    return particles_manager.get(id)
end

function module.emit(origin, count, preset, extension)
    local id = particles_manager.emit(origin, count, preset, extension)
    return Particles.new(id)
end

return module