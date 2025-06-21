local wraps = start_require "lib/private/gfx/blockwraps_manager"
local module = {}

local defaultFunctions = {
    "unwrap",
    "set_pos", "set_texture"
}

for _, key in ipairs(defaultFunctions) do
    module[key] = wraps[key]
end

local BlockWrap = {}
BlockWrap.__index = BlockWrap

function BlockWrap.new(id, pos, texture)
    local self = setmetatable({}, BlockWrap)

    self.id = id
    self.pos = pos
    self.texture = texture

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

function module.wrap(position, texture)
    local id = wraps.wrap(position, texture)
    return id, BlockWrap.new(id, position, texture)
end

return module