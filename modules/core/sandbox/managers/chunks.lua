local module = {}

--[[
pid: {
    x/z = true
}
]]
local loaded_chunks = {}

local CHUNK_SIZE_X = 16
local CHUNK_SIZE_Z = 16

local function in_distance(px, pz, cx, cz, view_distance, padding)
    local player_chunk_x = math.floor(px / CHUNK_SIZE_X)
    local player_chunk_z = math.floor(pz / CHUNK_SIZE_Z)

    local dx = cx - player_chunk_x
    local dz = cz - player_chunk_z

    local R = view_distance + padding

    return (dx * dx + dz * dz) <= (R * R)
end

function module.unload_player(player_obj)
    loaded_chunks[player_obj.pid] = nil
end

function module.load_chunk(player_obj, x, z)
    local pid = player_obj.pid
    if not loaded_chunks[pid] then loaded_chunks[pid] = {} end

    loaded_chunks[pid][x .. "/" .. z] = true
end

function module.is_loaded(player_obj, cx, cz)
    local pid = player_obj.pid
    local px, _, pz = player.get_pos(pid)

    if not loaded_chunks[pid] then loaded_chunks[pid] = {} end

    local in_chunks = loaded_chunks[pid][cx .. "/" .. cz]
    local in_dist = in_distance(
        px, pz,
        cx, cz,
        player_obj.view_distance,
        player_obj.view_padding
    )

    if not in_dist then
        loaded_chunks[pid][cx .. "/" .. cz] = nil
        return false
    end

    return in_chunks
end

return module
