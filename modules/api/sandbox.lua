local sandbox = require "lib/private/sandbox/sandbox"
local player_class = require "lib/private/sandbox/classes/player"

local module = {
    players = {},
    world = {}
}

function module.players.get_all()
    local players = sandbox.get_players()

    return table.map(players, function (_, player)
        return {
            pid = player.pid,
        }
    end)
end

--return module