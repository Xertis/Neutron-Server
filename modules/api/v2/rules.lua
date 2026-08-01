local sandbox = import "core/sandbox/methods"
local rules = import "core/sandbox/managers/rules"

local module = {
    players = {},
    worlds = {}
}

local function ensure_rule(rule)
    if not rule then
        error("rule must not be nil — did you forget to call get_rule(name) first?")
    end
end

function module.players.get_value(player, rule)
    ensure_rule(rule)
    return sandbox.get_player_rule(player, rule)
end

function module.players.get_all_values(player)
    return sandbox.get_all_values(player)
end

function module.players.set_value(player, rule, value)
    ensure_rule(rule)
    sandbox.set_player_rule(player, rule, value)
end

function module.players.reset_value(player, rule)
    ensure_rule(rule)
	sandbox.set_player_rule(player, rule, rule.default)
end

function module.worlds.get_value(world, rule)
    ensure_rule(rule)
    return sandbox.get_world_rule(world, rule)
end

function module.worlds.set_value(world, rule, value)
    ensure_rule(rule)
    sandbox.set_world_rule(world, rule, value)
end

function module.worlds.reset_value(world, rule)
    ensure_rule(rule)
    sandbox.set_world_rule(world, rule, rule.default)
end

module.define = rules.define
module.define_if_absent = rules.define_if_absent
module.is_defined = rules.is_defined
module.get_rule = rules.get_rule
module.get_registered = rules.get_registered

return module
