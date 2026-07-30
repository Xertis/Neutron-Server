local sandbox = import "core/sandbox/methods"
local rules = import "core/sandbox/managers/rules"

local module = {
    players = {},
    worlds = {}
}

function module.players.get_rule(player, rule)
    return sandbox.get_player_rule(player, rule)
end

function module.players.get_all_values(player)
    return sandbox.get_all_values(player)
end

function module.players.set_rule(player, rule, value)
    sandbox.set_player_rule(player, rule, value)
end

function module.worlds.get_rule(world, rule)
    return sandbox.get_world_rule(world, rule)
end

function module.worlds.set_rule(world, rule, value)
    sandbox.set_world_rule(world, rule, value)
end

module.define = rules.define
module.define_if_absent = rules.define_if_absent
module.is_defined = rules.is_defined
module.get_rule = rules.get_rule

return module
