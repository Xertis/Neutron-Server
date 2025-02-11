local protect = require "lib/private/protect"
local metadata = require "lib/private/files/metadata"
local module = {}

function module.join_player(cplayer)
    local status = cplayer:revive()
    if status == SANDBOX.codes.players.DataLoss then
        cplayer.pid = player.create(cplayer.username)
        cplayer.entity_id = player.get_entity(cplayer.pid)
        cplayer.active = true
        cplayer.role = CONFIG.roles.default_role
    elseif status == SANDBOX.codes.players.ReviveSuccess then
        cplayer.pid = player.create(cplayer.username)
        cplayer.entity_id = player.get_entity(cplayer.pid)
    elseif status == SANDBOX.codes.players.WrongPassword then
        logger.log(string.format('Player "%s" entered an incorrect password.', cplayer.username))
        return
    end

    logger.log(string.format('Player "%s" join the game.', cplayer.username))
end

return protect.protect_return(module)