require "std/stdmin"

local protect = require "lib/private/protect"
local hash = require "lib/private/hash"

local lib = {
    server = {},
    world = {},
    hash = hash
}

---WORLD---

function lib.world.preparation_main()
    --Загружаем мир
    local packs = table.copy(CONFIG.game.content_packs)
    app.reconfig_packs(CONFIG.game.content_packs, {})

    if not file.exists("user:worlds/" .. CONFIG.game.main_world .. "/world.json") then
        logger.log("Creating a main world")
        local name = CONFIG.game.main_world
        app.new_world(
            CONFIG.game.main_world,
            CONFIG.game.worlds[name].seed,
            CONFIG.game.worlds[name].generator
        )

        app.close_world(true)
    end
end

function lib.world.open_main()
    logger.log("Discovery of the main world")
    app.open_world(CONFIG.game.main_world)
end

return protect.protect_return(lib)