local protect = require "lib/private/protect"

if protect.protect_require() then return end

local module = {}
local WRAPS = {}

local NEXT_ID = 1

local function ensureWrap(id)
    if not WRAPS[id] then
        error 'undefined wrap'
    end
end

local function ensureVec3(vec)
    if type(vec) ~= "table" or #vec ~= 3 then
        error 'invalid vec3'
    end
end

function module.wrap(pos, texture)
    ensureVec3(pos)

    local id = NEXT_ID

    WRAPS[id] = {
        pos = pos,
        texture = texture,
        id = id
    }

    NEXT_ID = NEXT_ID + 1

    return id
end

function module.unwrap(id)
    ensureWrap(id)
    WRAPS[id] = nil
end

function module.set_pos(id, pos)
    ensureWrap(id)
    ensureVec3(pos)
    WRAPS[id].pos = pos
end

function module.set_texture(id, texture)
    ensureWrap(id)
    WRAPS[id].texture = texture
end

function module.get_in_radius(x, z, radius)
    local wraps = {}

    for _, wrap in pairs(WRAPS) do
        local pos = wrap.pos

        if math.euclidian2D(x, z, pos[1], pos[3]) <= radius then
            table.insert(wraps, wrap)
        end
    end

    return wraps
end

return module