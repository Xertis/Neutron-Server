function world.preparation_main()
    --Загружаем мир
    if not file.exists("user:worlds/" .. CONFIG.game.main_world .. "/world.json") then
        server.log("Creating a main world")
        local name = CONFIG.game.main_world
        app.new_world(
            CONFIG.game.main_world,
            CONFIG.game.worlds[name].seed,
            CONFIG.game.worlds[name].generator
        )

        app.close_world(true)
    end
end

function world.open_main()
    server.log("Discovery of the main world")
    app.open_world(CONFIG.game.main_world)
end