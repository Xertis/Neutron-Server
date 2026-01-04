local server_echo = start_require "server:multiplayer/server/server_echo"
local protocol = start_require "server:multiplayer/protocol-kernel/protocol"
local wraps = start_require "lib/private/gfx/blockwraps_manager"

local global_gfx = _G["gfx"]

function global_gfx.blockwraps.wrap(pos, texture, emission)
    emission = emission or 1

    return wraps.wrap(pos, texture, emission)
end

function global_gfx.blockwraps.unwrap(id)
    wraps.unwrap(id)
end

function global_gfx.blockwraps.set_pos(id, pos)
    wraps.set_pos(id, pos)
end

function global_gfx.blockwraps.set_texture(id, texture)
    wraps.set_texture(id, texture)
end

function global_gfx.blockwraps.set_faces(id, face1, face2, face3, face4, face5, face6)
    wraps.set_faces(id, face1, face2, face3, face4, face5, face6)
end

function global_gfx.blockwraps.set_tints(id, face1, face2, face3, face4, face5, face6)
    wraps.set_tints(id, face1, face2, face3, face4, face5, face6)
end