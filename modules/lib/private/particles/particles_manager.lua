local protect = require "lib/private/protect"

if protect.protect_require() then return end

local bson = require "lib/private/files/bson"

local module = {}

local PARTICLES = {}
local READ_PATH = string.format("user:worlds/%s/server_resources/particles.bson", CONFIG.game.main_world)
local WRITE_PATH = "world:server_resources/particles.bson"
local MAX_PID = 0

events.on("server:save", function ()
    file.mktree(
        WRITE_PATH,
        bson.serialize({
            max_pid = MAX_PID,
            ["particles"] = table.to_serializable(PARTICLES)
        })
    )
end)

function module.load()
    if file.exists(READ_PATH) then
        local data = bson.deserialize(file.read_bytes(READ_PATH))
        MAX_PID = data.max_pid
        PARTICLES = data["particles"]
    end
end

function module.emit(origin, count, preset, extension)
    local pid = MAX_PID

    functions.args_check("emit", {origin = origin or false, count = count or false, preset = preset or false})

    PARTICLES[tohex(pid)] = {
        origin = origin,
        count = count,
        preset = preset,
        extension = extension,
        pid = pid
    }

    MAX_PID = MAX_PID + 1
    return pid
end

function module.stop(pid)
    PARTICLES[tohex(pid)] = nil
end

function module.get(pid)
    return PARTICLES[tohex(pid)]
end

local function half_get_pos(particle)
    if not particle.origin then return end

    if type(particle.origin) == "number" then
        local entity = entities.get(particle.origin)
        if not entity then return end

        return entity.transform:get_pos()
    end

    return particle.origin
end

function module.get_pos(pid)
    local particle = PARTICLES[tohex(pid)]

    if not particle then return end

    return half_get_pos(particle)
end

function module.get_in_radius(x, z, radius)
    local particles = {}

    for _, particle in pairs(PARTICLES) do
        local pos = half_get_pos(particle)
        if pos then
            if math.euclidian2D(x, z, pos[1], pos[3]) <= radius then
                table.insert(particles, particle)
            end
        end
    end

    return particles
end

module.load()

return module