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
    app.reconfig_packs(table.freeze_unpack(CONFIG.game.content_packs), {})

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

return protect.protect_return(lib)