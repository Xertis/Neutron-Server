local wraps = start_require "lib/private/gfx/blockwraps_manager"
local module = {}

local defaultFunctions = {
    "unwrap",
    "set_pos", "set_texture",
    "set_faces", "set_tints"
}

for _, key in ipairs(defaultFunctions) do
    module[key] = wraps[key]
end

local BlockWrap = {}
BlockWrap.__index = BlockWrap

function BlockWrap.new(id, pos, texture, emission)
    local self = setmetatable({}, BlockWrap)

    self.id = id
    self.pos = pos
    self.texture = texture
    self.emission = emission
    self.faces = {}
    self.tints = {}

    return self
end

function BlockWrap:unwrap()
    if self.id then
        wraps.unwrap(self.id)
        self.id = nil
    end
end

function BlockWrap:set_pos(position)
    if self.id then
        self.pos = position
        wraps.set_pos(self.id, position)
    end
end

function BlockWrap:set_texture(texture)
    if self.id then
        self.texture = texture
        wraps.set_texture(self.id, texture)
    end
end

function BlockWrap:get_pos()
    return self.pos
end

function BlockWrap:get_texture()
    return self.texture
end

function BlockWrap:set_faces(face1, face2, face3, face4, face5, face6)
    self.faces = {
        face1,
        face2,
        face3,
        face4,
        face5,
        face6
    }

    wraps.set_faces(self.id, face1, face2, face3, face4, face5, face6)
end

function BlockWrap:set_tints(face1, face2, face3, face4, face5, face6)
    self.tints = {
        face1,
        face2,
        face3,
        face4,
        face5,
        face6
    }

    wraps.set_tints(self.id, face1, face2, face3, face4, face5, face6)
end

function module.wrap(position, texture, emission)
    local id = wraps.wrap(position, texture, emission)
    return id, BlockWrap.new(id, position, texture, emission)
end

return module