local sandbox = require "lib/private/sandbox/sandbox"

local module = {
    players = {},
    world = {}
}

function module.players.get_all()
    local players = sandbox.get_players()

    return players
end

return module