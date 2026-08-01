local rules = {}

local Rule = {}
Rule.__index = Rule

local registered = {}

local LEVELS = { player = true, world = true }
function Rule.new(name, default, level)
    if registered[name] then
        error(string.format("A rule named '%s' already exists in %s-rules", name, registered[name].level))
    end
    if not LEVELS[level] then
        error(string.format("Unknown rule level '%s' for rule '%s'", tostring(level), name))
    end

    local self = setmetatable({}, Rule)

    self.name = name
    self.default = default
    self.level = level

    self.next_listener_id = 0
    self.listeners = {}

    registered[name] = self

    return self
end

function Rule:listen(listener)
    local id = tohex(self.next_listener_id)
    self.listeners[id] = listener
    self.next_listener_id = self.next_listener_id + 1
    return id
end

function Rule:unlisten(id)
    self.listeners[id] = nil
end

function Rule:process(obj, value)
    for _, listener in pairs(self.listeners) do
        listener(obj, value)
    end
end

local function stores(rule, player, world)
    if rule.level == "player" then
        return player.rules, world and world.rules or nil
    else
        return world.rules, player and player.rules or nil
    end
end

local function migrate(rule, own, foreign)
    if not foreign then return end

    if own[rule.name] == nil and foreign[rule.name] ~= nil then
        own[rule.name] = foreign[rule.name]
        foreign[rule.name] = nil
        logger.log(string.format(
            "Rule '%s' value has been migrated to '%s'-level storage after a level change",
            rule.name, rule.level))
    elseif foreign[rule.name] ~= nil then
        foreign[rule.name] = nil
    end
end

function rules.define(name, properties)
    properties = properties or {}
    return Rule.new(name, properties.default, properties.level)
end

function rules.define_if_absent(name, properties)
    return registered[name] or rules.define(name, properties)
end

function rules.is_defined(name)
    return registered[name] ~= nil
end

function rules.get_rule(name)
    return registered[name]
end

function rules.get_registered()
    return registered
end

function rules.get_value(player, world, rule)
    local own, foreign = stores(rule, player, world)
    migrate(rule, own, foreign)

    local value = own[rule.name]
    if value == nil then value = rule.default end
    return value
end

function rules.set_value(player, world, rule, value)
    local own, foreign = stores(rule, player, world)
    migrate(rule, own, foreign)

    own[rule.name] = value
    rule:process(rule.level == "player" and player or world, value)

    return value
end

function rules.get_all_values(player, world)
    local result = {}
    for name, rule in pairs(registered) do
        result[name] = rules.get_value(player, world, rule)
    end
    return result
end

return rules
