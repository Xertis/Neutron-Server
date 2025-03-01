require "std/stdmin"

local protect = require "lib/private/protect"
local hash = require "lib/private/hash"

local lib = {
    server = {},
    world = {},
    roles = {},
    hash = hash
}

---WORLD---

function lib.world.preparation_main()
    --Загружаем мир
    local packs = table.freeze_unpack(CONFIG.game.content_packs)
    table.insert(packs, "server")

    app.config_packs(packs)
    app.load_content()

    if not file.exists("user:worlds/" .. CONFIG.game.main_world .. "/world.json") then
        logger.log("Creating a main world...")
        local name = CONFIG.game.main_world
        app.new_world(
            CONFIG.game.main_world,
            CONFIG.game.worlds[name].seed,
            CONFIG.game.worlds[name].generator
        )

        logger.log("Loading chunks...")
        player.create("server")
        local ctime = time.uptime()

        while world.count_chunks() < 12*CONFIG.server.chunks_loading_distance do
            app.tick()

            if ((time.uptime() - ctime) / 60) > 1 then
                logger.log("Chunk loading timeout exceeded, exiting. Try changing the chunks_loading_speed.", "W")
                break
            end
        end

        logger.log("Chunks loaded successfully.")

        app.close_world(true)
    end
end

function lib.world.open_main()
    logger.log("Discovery of the main world")
    app.open_world(CONFIG.game.main_world)
end

function lib.roles.is_higher(role1, role2)
    if role1.priority > role2.priority then
        return true
    end

    return false
end

function lib.roles.exists(role)
    return CONFIG.roles[role] and true or false
end

return protect.protect_return(lib)