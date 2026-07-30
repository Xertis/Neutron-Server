import "init/cmd"

local rules = import "core/sandbox/managers/rules"

for _, role in pairs(CONFIG.roles) do
    for name, default in pairs(role.rules) do
        rules.define_if_absent(name, { default = default, level = "player" })
    end
end

for name, default in pairs(CONFIG.game.worlds[CONFIG.game.main_world].rules or {}) do
    rules.define_if_absent(name, { default = default, level = "world" })
end
