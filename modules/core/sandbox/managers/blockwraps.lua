local chunks_manager = import "core/sandbox/managers/chunks"

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

function module.wrap(pos, texture, emission)
    ensureVec3(pos)

    local id = NEXT_ID

    WRAPS[id] = {
        pos = pos,
        texture = texture,
        emission = emission,
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

function module.set_faces(id, face1, face2, face3, face4, face5, face6)
    ensureWrap(id)
    WRAPS[id].faces = {
        face1,
        face2,
        face3,
        face4,
        face5,
        face6
    }
end

function module.set_tints(id, face1, face2, face3, face4, face5, face6)
    ensureWrap(id)
    WRAPS[id].tints = {
        face1,
        face2,
        face3,
        face4,
        face5,
        face6
    }
end

function module.get_in_radius(player_obj)
    local wraps = {}

    local radius = player_obj.view_distance
    local x, y, z = player.get_pos(player_obj.pid)

    for _, wrap in pairs(WRAPS) do
        local pos = wrap.pos

        if math.euclidian2D(x, z, pos[1], pos[3]) <= radius * 16 then
            if chunks_manager.is_loaded(player_obj, math.floor(pos[1] / 16), math.floor(pos[3] / 16)) then
                table.insert(wraps, wrap)
            end
        end
    end

    return wraps
end

return module
