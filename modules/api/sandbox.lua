local sandbox = require "lib/private/sandbox/sandbox"

local module = {
    players = {},
    world = {}
}

function module.players.get_all()
    local players = sandbox.get_players()

    return players
end

function module.players.get_in_radius(target_pos, radius)
    target_pos = target_pos or {}

    if not target_pos.x or not radius then
        error("missing position or radius")
    end

    local res = {}
    local x, y, z = target_pos.x, target_pos.y, target_pos.z

    for key, _player in pairs(sandbox.get_players()) do
        local x2, y2, z2 = player.get_pos(_player.pid)

        if math.euclidian(x, y, z, x2, y2, z2) <= radius then
            res[key] = _player
        end
    end

    return res
end

return module